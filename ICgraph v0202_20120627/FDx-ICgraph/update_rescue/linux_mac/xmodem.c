/*
 *  Barixload - a loader for Barix devices
 *
 *  Copyright (C) 2006 Barix AG Switzerland http://www.barix.com
 *  Written by Karel Kulhavy
 *
 * ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or (at
 *  your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful, but
 *  WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 *  General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License along
 *  with this program; if not, write to the Free Software Foundation, Inc.,
 *  59 Temple Place, Suite 330, Boston, MA 02111-1307 USA.
 *
 * ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
 */

#include <sys/select.h>
#include <sys/time.h>
#include <errno.h>
#include <string.h>

#include "main.h"
#include "xmodem.h"

/* Returns in seconds */
static double double_time(void)
{
	struct timeval tv;
#ifdef DST_NONE
	struct timezone tz={0,DST_NONE};
#else
	struct timezone tz={0,0};
#endif

	if (gettimeofday(&tv, &tz)<0)
		PERR("cannot get time of day.");
	return (double)tv.tv_usec/1000000+tv.tv_sec;
}

static unsigned crc_16_xmodem(unsigned char *ptr, unsigned count)
{
  unsigned short crc;
  unsigned char i;

  crc = 0;
  for (;count;count--){
    crc = crc ^ (unsigned short) *ptr++ << 8;
    for (i=8;i;i--){
      if (crc & 0x8000) crc = crc << 1 ^ 0x1021;
      else crc = crc << 1;
    }
  }
  return (crc);
}

static void double2timeval(struct timeval *tv, double d)
{
	tv->tv_sec=d;
	tv->tv_usec=(d-tv->tv_sec)*1000000;
}

char *charnames[32]={
	"NUL", "SOH", "STX", "ETX", "EOT",
	"ENQ", "ACK", "BEL", "BS", "HT",
	"LF", "VT", "FF", "CR", "SO",
	"SI", "DLE", "DC1", "DC2", "DC3",
	"DC4", "NAK", "SYN", "ETB", "CAN",
	"EM", "SUB", "ESC", "FS", "GS",
	"RS", "US"};
void print_serial_char(unsigned char c)
{
	if (c>=32&&c<127) putchar(c);
	else if (c<32) printf("[%s]",charnames[c]);
	else if (c==127) printf("[DEL]");
	else printf("[0x%02X]",c);
}

/* The argument is the first character that would be normally still in the
 * serial port, but which was already consumed by the caller to determine
 * what to do. */
static void flush_print_serial_newline(unsigned char c)
{
	do
		print_serial_char(c);
	while(my_read(port_handle, &c, 1, (unsigned char *)"serial port"));
	putchar('\n');
}

/* Reads out possible garbage from the line and if there's any,
 * informs the user about it's presence. The when is a string that
 * says when it would possibly happen. Returns 0 if nothing or garbage
 * was encountered, and 1 if the device canceled the transfer. */
int consume_garbage(unsigned char *when)
{
	unsigned char c;

	if (!my_read(port_handle, &c, 1
        , (unsigned char *)"the serial port")) return 0;
	if (c==CAN) return 1;
	printf("Garbage received %s: ", when);
	print_serial_char(c);
	while (my_read(port_handle, &c, 1, (unsigned char *)"the serial port")){
		if (c==CAN){
			putchar('\n');
			return 1;
		}
		print_serial_char(c);
	}
	putchar('\n');
	return 0;
}

/* 0=data available, 1=timeout occured. */
int wait_for_available_data(double timeout)
{
	double timeout_tv; /* The time when the waiting times out */
	double current;
	struct timeval tv;
	int rv;
	fd_set readfds;

	/* Add timeout */
	timeout_tv=double_time()+timeout;
again:
	current=double_time();
	if (current>=timeout_tv){
		return 1; /* Timeout has already happened */
	}
	double2timeval(&tv, timeout_tv-current);
	if (!(tv.tv_usec||tv.tv_sec)){
		return 1; /* Timeout is just happening */
	}
	FD_ZERO(&readfds);
	FD_SET(port_handle, &readfds);
	rv=select(port_handle+1, &readfds, NULL, NULL, &tv);
	if (!rv) {
		return 1; /* Timeout */
	}
	if (rv<0){
		if (errno==EINTR) goto again;
		PERR("Cannot wait on the serial port using select");

	}
	return 0;
}

/* Uses 1.5-second timeout to get the reply.
 * Return value: -1=no response received within timeout
 * Otherwise the received response character
 * ACK=received an ACK
 * NAK=received a NAK
 * C=received 'C'
 *
 * Response type: 'C' or ACK. 'C' means everything except 'C' is
 * invalid. ACK means everything except ACK and NAK is invalid. CAN
 * is checked in this function too and bails out of the program.
 */
static int check_xmodem_response(int response_type)
{
	unsigned char c;

spurious_select:
	if (wait_for_available_data(10)){
		/* Timeout occured */
		return 0;
	}
	if (!my_read(port_handle, &c, 1, (unsigned char *)"the serial port"))
		goto spurious_select;
	/* See man select, BUGS */
	switch(response_type){
		case ACK:
			if (c==ACK||c==NAK){
				if (consume_garbage((unsigned char *)(c==ACK?
						"After xmodem ACK"
						:"After xmodem NAK")))
					goto can;
				return c;
			}
			break;
		case 'C':
			if (c=='C'){
				if (consume_garbage((unsigned char *)"After xmodem 'C'"))
					goto can;
				return c;
			}
			break;

	}
	if (c==CAN) {
can:
		ERR("The device canceled the transfer.");
	}
	printf("Invalid response from the device: ");
	flush_print_serial_newline(c);
	return c;
}

/* If the block is NULL, block number is reset to 0 and nothing
 * else is done. If len is less than 1024, automatically pads with
 * zeroes. The maximum allowed value of len is 1024 and minimum
 * allowed is 0.
 *
 * Automatically does 10 retries. Must not be used to handle multiple
 * xmodem transmissions at a time because contains a static counter
 * variable. */
void send_xmodem_block(unsigned char *block, unsigned len)
{
	unsigned char hdr[3]={STX};
	unsigned char *trailer=hdr+1; /* Recycle the space ;-) */
	static unsigned block_number;
	unsigned short crc;
	unsigned retries=10;
	int response;
	unsigned char not_yet_printed=1;

	if (!block){
		block_number=1;
		return;
	}

	printf("Sending KiB %u.\r",block_number);
        fflush(stdout);
	if (len<1024){
		/* Turn the block pointer into a temporarily
		 * allocated 1024-byte zero-padded block :) */
		unsigned char *block1;
		block1=mem_alloc(1024);
		memcpy(block1, block, len);
		memset(block1+len, 0, 1024-len);
		block=block1;
	}
retry:
	hdr[1]=block_number;
	hdr[2]=255-(block_number&255);
	my_write(port_handle, hdr, sizeof(hdr), (unsigned char *)"serial port");
	my_write(port_handle, block, 1024, (unsigned char *)"serial port");
	if (consume_garbage((unsigned char *)"during xmodem block transmission"))
		ERR("The device canceled the transfer.");
	crc=crc_16_xmodem(block, 1024);
	trailer[0]=crc>>8;
	trailer[1]=crc;
	my_write(port_handle, trailer, 2, (unsigned char *)"serial port");
	response=check_xmodem_response(ACK);
	switch(response){
		case ACK:
			block_number++;
			if (len<1024) free(block);
			/* Free only if we temporarily allocated */
			return;
		default:
			if (not_yet_printed)
			printf("There was an error in xmodem block "
				"transmission. A possible cause is that the "
				"device has a problem or the serial "
				"port connection is dodgy. Check your "
				"cable and make sure the connectors are "
				"bolted down firmly on both sides of the "
				"cable.\n");
			else printf("Again an error in block "
				"transmission...\n");
			not_yet_printed=0;
	}
	retries--;
	if (!retries){
		/* We don't free here because the program will exit
		 * anyway. */
		ERR("tried to send a xmodem packet 10 times and failed."
				" The xmodem transfer is unsuccessful.\n");
	}
	goto retry;
}

/* Call this before sending the first block. */
void init_xmodem(void)
{
	send_xmodem_block(NULL, 0); /* Reset the block number to zero. */
retry:
	switch (check_xmodem_response('C')){
		case -1:
			ERR("The device doesn't start xmodem transmission");
		case 'C':
			return;
	}
	/* Here we got some garbage */
	goto retry;
}

void close_xmodem(void)
{
	unsigned char eot[]={EOT};
	my_write(port_handle, eot, sizeof(eot), (unsigned char *)"serial port");
}

