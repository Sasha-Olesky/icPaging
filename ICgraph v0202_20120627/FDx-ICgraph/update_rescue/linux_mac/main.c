/*
 *  A loader for Barix devices - the main source file
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

#include <termios.h>
#include <unistd.h>
#include <sys/select.h>
#define _GNU_SOURCE
#include <string.h>
#define _XOPEN_SOURCE 500
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <errno.h>
#include <sys/time.h>
#include <time.h>

#include "main.h"
#include "xmodem.h"
#include "sdb.h"

/* The informative messages (messages that are not associate with program
 * abort) are sent to stdout. Error messages (when the program aborts)
 * are sent to stderr. */

#define TYPE_DEFAULT 0
#define TYPE_BARIONET 1

unsigned char device_type=TYPE_DEFAULT;
int port_handle; /* Serial port port_handle */
const unsigned char *fname=(unsigned char *)"/dev/ttyS0";
speed_t speed=B115200;
unsigned long magic_wait; /* For POSIX violating implementations of tcdrain */

int bootloader_handle=-1;
unsigned char bootloader_is_binary; /* Means that it is not in the sdb format.
                                     */
unsigned char *flash_bootloader_filename; /* Bootloader file which will be loaded
                                         into the flash */

int config_handle=-1;
int keyfile_handle=-1;
unsigned char * dlraw_filename=NULL;

unsigned char erase_ee, erase_pf;
int new_device;
unsigned char *datafiles; /* A data block with concatenated strings, in the
			     same order as they were on the command line. */
unsigned datafiles_size;

void my_tcgetattr(int port_handle, struct termios *t)
{
	if (tcgetattr(port_handle, t)<0){
		fprintf(stderr, PROGNAME": cannot get attributes of %s: ",
				fname);
		perror("");
		exit(-1);
	}
}

/* Zero is allowed, too. Zero sleep sleeps exactly zero (well apart from
 * the execution time of the test). */
void my_usleep(unsigned long usec)
{
	struct timespec ts;

  if (!usec) return;

	ts.tv_sec=usec/1000000;
	ts.tv_nsec=1000*(usec%1000000);

resume:
	if (nanosleep(&ts, &ts)<0){
		if (errno==EINTR) goto resume;
		PERR("nanosleep failed");
	}
}

void my_tcsetattr(int port_handle, const struct termios *t)
{
	/* We are putting the tcdrain before the tcsetattr to make it
         * work even on platforms that don't support TCSADRAIN. */ 
retry_tcdrain:
	if (tcdrain(port_handle)<0){
		if (errno==EINTR||errno==EAGAIN) goto retry_tcdrain;

		fprintf(stderr, PROGNAME": cannot drain %s: ",
				fname);
		perror("");
		exit(-1);
	}

  if (magic_wait)
    my_usleep(magic_wait); /* Workaround for POSIX violating tcdrain
                              implementations like Linux with USB/serial
                              dongle or Cygwin. */

retry_tcsetattr:
	if (tcsetattr(port_handle, TCSADRAIN, t)<0){
		if (errno==EINTR||errno==EAGAIN) goto retry_tcsetattr;
		fprintf(stderr, PROGNAME": cannot set attributes on %s: ",
				fname);
		perror("");
		exit(-1);
	}
}

/* Sets the terminal speed to the global variable speed. */
void my_cfsetspeed(struct termios *t)
{
	if (cfsetispeed(t, speed)<0){
		PERR("cannot set input speed");
	}
	if (cfsetospeed(t, speed)<0){
		PERR("cannot set output speed");
	}
}

unsigned speed_t2baud(speed_t spt)
{
  unsigned baud=0;

  switch(spt){
    case B0:       baud=0; break;
    case B50:      baud=50; break;
    case B75:      baud=75; break;
    case B110:     baud=110; break;
    case B134:     baud=134; break;
    case B150:     baud=150; break;
    case B200:     baud=200; break;
    case B300:     baud=300; break;
    case B600:     baud=600; break;
    case B1200:    baud=1200; break;
    case B1800:    baud=1800; break;
    case B2400:    baud=2400; break;
    case B4800:    baud=4800; break;
    case B9600:    baud=9600; break;
    case B19200:   baud=19200; break;
    case B38400:   baud=38400; break;
    case B57600:   baud=57600; break;
    case B115200:  baud=115200; break;
    case B230400:  baud=230400; break;
  }

  return baud;
}


/* Sets the serial speed to the global variable speed. */
void set_speed(void)
{
  speed_t current_ispeed;
  speed_t current_ospeed;
	struct termios t;

	my_tcgetattr(port_handle, &t);
	my_cfsetspeed(&t);
	my_tcsetattr(port_handle, &t);
  my_tcgetattr(port_handle, &t);
  current_ispeed=cfgetispeed(&t);
  current_ospeed=cfgetospeed(&t);
  if (speed!=current_ispeed||speed!=current_ospeed){
    /* Error */
    fprintf(stderr, PROGNAME ": Tried to set the speed to %u Baud, but ",
        speed_t2baud(speed));
    if (current_ispeed==current_ospeed){
      fprintf(stderr, "the speed remains at %u Baud.\n",
          speed_t2baud(current_ispeed));
    }else{
      if (current_ispeed!=speed)
        fprintf(stderr,"the input speed remains at %u Baud",
            speed_t2baud(current_ispeed));
      if (current_ospeed!=speed){
        if (current_ispeed!=speed) fprintf(stderr," and ");
        fprintf(stderr,"the output speed remains at %u Baud",
            speed_t2baud(current_ospeed));
      }
      fprintf (stderr,".\n");
    }
    exit(1);
  }
}

/* Prints a special message to aid the user diagnose his problem with
 * serial port, depending on global variable errno. */
void special_messages(void)
{
	switch (errno)
	{
		case EACCES:
#ifdef __CYGWIN__
			fprintf(stderr,"This can be caused by some other"
					" program using the serial port (exit"
					" that program), or by a mouse driver"
					" using the serial port (use another"
					" port).\n");
#else
			fprintf(stderr,"Please note that you have to become"
					"the root to be able to access the "
					"serial port! Use the \"su\" or "
					"\"sudo\" command to become the root."
					"\n");
#endif
			break;
		case ENXIO:
		case ENODEV:
			fprintf(stderr,"You are probably trying to use a"
					" serial port which doesn't exist"
					" in your PC or is not enabled in"
					" your BIOS or operating system."
					" Use another port or make sure this"
					" one exists and is enabled.\n");
			break;
	}
}

/* Takes care of the O_BINARY workaround.
 * retry means that /dev/ttyS0 is retried to /dev/tty00 etc.
 * 20110728 KS Corrections:
 * - sizeof(linux_devstring-1) => sizeof(linux_devstring)-1)
 * - for CYGWIN outputs invalid serial device number# as COM#
 * */

int my_open(const unsigned char *path, int flags,
    int retry)
{
	int fd;
	int devno=0;
	const unsigned char devstring[]="/dev/";
  const unsigned char linux_devstring[]="/dev/ttyS"; /* This must not be a
                                                        prefix of
                                                        openbsd_devstring */
  static unsigned char openbsd_devstring[]="/dev/tty00";

#ifdef O_BINARY
  flags|=O_BINARY; /* Fix for Cygwin's O_BINARY */
#endif
again:
	fd=open((char *)path, flags, S_IRUSR|S_IWUSR|S_IRGRP|S_IROTH);
	if (fd<0){
		if (errno==EINTR||errno==EAGAIN) goto again;
    if (errno==ENOENT&&!strncmp((char *)path,(char *)linux_devstring,
          sizeof(linux_devstring)-1)){
      //int devno=atoi((char *)(path+sizeof(linux_devstring-1)));
      devno=atoi((char *)(path+sizeof(linux_devstring)-1)); // -1 in wrong place
      sprintf((char *)openbsd_devstring,"/dev/tty%02u", devno);
// TEST
      //fprintf(stderr, PROGNAMEE "path:%s ",path);
      //fprintf(stderr, PROGNAMEE "path+:%s ",path+sizeof(linux_devstring)-1);
      //fprintf(stderr, PROGNAMEE "devno:%u ",devno);
// END TEST
      path=openbsd_devstring;
      goto again;
    }
#ifdef __CYGWIN__
        fprintf(stderr, PROGNAMEE "Cannot open COM%u: ",devno+1);
#else
		fprintf(stderr, PROGNAMEE "Cannot open file %s: ",
				path);
#endif
		perror("");
		if (!memcmp(path, devstring, sizeof(devstring)-1))
			special_messages();
		exit(-1);
	}
	return fd;
}

void my_close(int fd)
{
retry:
	if (close(fd)<0){
		if (errno==EINTR) goto retry;
		PERR("Cannot close a file");
	}
}

/* Opens the serial port and sets all parameters necessary, including
 * the speed. */
void open_serial(void)
{
	struct termios t;

	port_handle=my_open(fname,O_RDWR|O_NONBLOCK|O_SYNC, 1);
	memset(&t, 0, sizeof(t));
	t.c_iflag|=IGNBRK|IGNPAR;
	t.c_cflag|=CS8|CREAD|CLOCAL;
	t.c_lflag|=NOFLSH;
	my_cfsetspeed(&t); /* Set the speed to the global variable speed. */
	my_tcsetattr(port_handle, &t);
}

/* Waits until it's possible to write into that file descriptor */
void wait_for_write_available(int fd)
{
	int rv;
	fd_set writefds;

retry:
	FD_ZERO(&writefds);
	FD_SET(fd, &writefds);
	rv=select(fd+1, NULL, &writefds, NULL, NULL);
	if (rv<0){
		if (errno==EINTR) goto retry;
		PERR("Cannot wait for write using select");

	}
}

/* Never returns with a failure. Never writes a short block. */
void my_write(int fd, const unsigned char *buf, size_t len, unsigned char *fname)
{
	ssize_t rv;

	while(len){
		rv=write(fd, buf, len);
		if (rv<0){
      if (errno==EAGAIN){
        wait_for_write_available(fd);
        continue;
      }
			if (errno==EINTR) continue;
			fprintf(stderr,PROGNAME ": cannot write into %s: ",
					fname);
			perror("");
			exit(-1);
		}
		buf+=rv;
		len-=rv;
	}
}

/* If there are no data available, 0 is returned. Never returns a negative
 * value. */
ssize_t my_read_vulnerable(int fd, unsigned char *buf, size_t len, const
    unsigned char *filename)
{
	ssize_t rv;

again:
	rv=read(fd, buf, len);
	if (rv<0)
		switch(errno){
			case EINTR:
				goto again;
			case EAGAIN:
				return 0;
			default:
				fprintf(stderr,PROGNAME": cannot read from %s:",
						filename);
				perror("");
				exit(-1);
		}
	return rv;
}

/* Like my_read_vulnerable, but makes sure that a coming signal doesn't cause
 * partially read buffer. May return 0. Short count returned always indicates
 * end of file.
 */
ssize_t my_read(int fd, unsigned char *buf, size_t len, const unsigned char
		*filename)
{
	ssize_t total=0;
	ssize_t rv;

while(len){
	rv=my_read_vulnerable(fd, buf, len, filename);
	if (!rv) return total;
	total+=rv;
	buf+=rv;
	len-=rv;
	}
	return total;
}

/* 1=occurs, 0=doesn't */
int occurence(const unsigned char *haystack, unsigned haystacklen,
		const unsigned char *needle, unsigned needlelen)
{
	unsigned i;

	if (haystacklen<needlelen) return 0;
	for (i=0;i<=haystacklen-needlelen;i++)
		if (!memcmp(haystack+i, needle, needlelen)) return 1;
	return 0;
}

void print_block(unsigned char *c, unsigned count)
{
	for (;count;count--){
		print_serial_char(*c++);
	}
	if (!count||c[-1]!='\n') putc('\n', stdout);
}

/* 1=got a successful reply, 0=didn't get one immediately.
 * You can call it even if the device didn't send anything. */
int check_reply(const unsigned char *template, unsigned len)
{
	unsigned char c[256];
	unsigned readbytes;

	readbytes=my_read(port_handle, c, sizeof(c)
      , (unsigned char *)"the serial port");
	if (!readbytes) return 0;
	if (occurence(c, readbytes, template, len)){
		return 1;
	}else{
		printf("Received improper response: ");
		print_block(c, readbytes);
	}
	return 0;
}

/* realloc with automatic error */
void *my_realloc(void *previous, size_t size)
{
	void *rv=realloc(previous, size);
	if (!rv&&size)
	{
		fprintf(stderr,PROGNAME ": Unable to allocate %u bytes of "
				" memory.\n",(unsigned)size);
		exit(-1);
	}
	return rv;
}

/* Adds a filename of data file into the datafiles string. It reallocates the
 * string to a bigger size. Changed variables: datafiles, datafiles_size. */
void register_datafile(unsigned char *filename)
{
	unsigned size=strlen((char *)filename)+1;
	datafiles=my_realloc(datafiles, datafiles_size+size);
	memcpy(datafiles+datafiles_size, filename, size);
	datafiles_size+=size;
}

#ifdef __CYGWIN__
/* Input must be a zero-terminated string */
const unsigned char *translate_com_name(const unsigned char *in)
{
  unsigned len=strlen((const char *)in);
  unsigned i;
  static unsigned char buffer[3+10+1];

  if (len<3) return in;
  if (memcmp(in,"COM",3)) return in; /* Not COM... */
  for (i=3;i<len;i++)
    if (in[i]<'0'||in[i]>'9') return in; /* Not digits */
  i=strtoul(in+3, NULL, 10);
  i--;
  sprintf(buffer, "/dev/ttyS%u" ,i);
  return buffer;
}
#endif

void parse_args(int argc, char **argv)
{
	unsigned char *ownname;
new_arg:
	switch(getopt(argc, argv, "b:c:d:efghik:m:nr:s:t:x:")){
		case 'h':
			ownname=(unsigned char *)(argc?argv[0]:"");
			fprintf(stderr,
"%s - the loader for Barix devices\n\n"
					"Usage: %s <arguments>\n"
					"Possible arguments:\n"

					"-b <bootloaderfile> loads the "
					"bootloader from"
					" that file. Mandatory unless "
					"-g is used.\n"

					"-c <configfile> Optional. Loads the"
					" config file into the device's "
					"EEPROM.\n"

					"-d <datafile> the compound file to "
					"actually "
					"upload. Optional. Can be present "
					"multiple times, in which case the "
					"files are loaded one after another "
					"in the specified sequence.\n"

					"-e Erase the EEPROM before"
					" loading the configfile.\n"

					"-f Erase the parallel flash"
					" before loading the compound"
					" file.\n"

					"-g generate compound file. If this "
					"option is used, then it must be the "
					"first one. Then optional flag -f "
					"may follow. Then filename must "
					"follow. Then every pair of following "
					"arguments is treated as filename "
					"(first) and address segment (second). "
					"If -f is not specified, "
					"the first entry in the output will be "
					"RST1 Seg:FFFF Off:0000 "
					"Len:00000000\\0. "
					"The segment can be given "
					"in decimal or in hexadecimal (0x...) "
					"or octal (0...).\n"

					"-h prints this help.\n"

          "-i the bootloader file is in binary format rather than SDB "
          "format which is the default.\n"
	  "-k <keyfile> copies filesystem encryption key from keyfile into the EEPROM. \n"

          "-m <milliseconds> performs a magic wait before setting the "
          "serial speed. This is a workaround for some POSIX violating "
          "implementations (Linux with USB/serial dongle and Cygwin) "
          "where the tcdrain function behaves wrong by returning "
          "prematurely. This corrupts the bootloader that is sent at the "
          "beginning and the unit doesn't start the bootloader and the "
          "rescue kit doesn't work.\n"

					"-n sets the speed for the newer "
					"device (EX, 57600) instead of the old "
					"one (LX, 115200) and "
					"doesn't update the bootloader.\n"

					"-r <filename> Download webpage into "
					"the barionet (dlraw sf 310). May be "
					"present only once.\n"

					"-s name of the serial device to "
					"which the device is connected. On Linux /dev/ttyS0 etc.,"
          " on Windows COM1 etc.\n"
					
					"-t <type> sets an alternative type "
					"of the device. Currently supported "
					"types: barionet. The type argument "
					"is case insensitive.\n"

          "-x <bootloader> flashes the bootloader with this "
          "file (normally the bootloader is not flashed).\n"

					"\n"
"Copyright (C) 2006 Barix AG Switzerland http://www.barix.com\n"
"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n"
" This program is free software; you can redistribute it and/or modify\n"
" it under the terms of the GNU General Public License as published by\n"
" the Free Software Foundation; either version 2 of the License, or (at\n"
" your option) any later version.\n"
"\n"
" This program is distributed in the hope that it will be useful, but\n"
" WITHOUT ANY WARRANTY; without even the implied warranty of\n"
" MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU\n"
" General Public License for more details.\n"
"\n"
" You should have received a copy of the GNU General Public License along\n"
" with this program; if not, write to the Free Software Foundation, Inc.,\n"
" 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA.\n"
"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n"
					,ownname, ownname

					);
			exit(0);
		case 'b':
			bootloader_handle=my_open((unsigned char *)optarg, O_RDONLY, 0);
			break;
		case 'c':
			config_handle=my_open((unsigned char *)optarg, O_RDONLY, 0);
			break;
		case 'd':
			register_datafile((unsigned char *)optarg);
			break;
		case 'e':
			erase_ee=1;
			break;
		case 'f':
			erase_pf=1;
			break;
		case 'g':
			ERR("The -g option must be as first.");
    case 'i':
      bootloader_is_binary=1;
      break;
		case 'k':
			keyfile_handle=my_open((unsigned char *)optarg, O_RDONLY, 0);
			break;
    case 'm':
      magic_wait=1000*strtoul(optarg, NULL, 10);
      break;        
		case 'n': /* The new series of devices */
			speed=B57600;
			new_device=1;
			break;
		case 'r':
			dlraw_filename=(unsigned char *)optarg;
			break;
		case 's':
			fname=(unsigned char *)optarg;
#ifdef __CYGWIN__
      fname=translate_com_name(fname);
#endif
			break;
		case 't':
			if (!strcasecmp(optarg,"barionet"))
				device_type=TYPE_BARIONET;
			break;
		case 'x':
      flash_bootloader_filename=(unsigned char *)optarg;
			break;
		case -1:
			return;
		default:
			fprintf(stderr, PROGNAMEE
					"internal error: unhandled option\n");
		case '?':
			exit(-1);
			
	}
	goto new_arg;
}

void get_initial_response(void)
{
	unsigned char buf[]={'!','D','L','\n'};
	const unsigned char response[]={0x47, 0xa};

	printf("\nPlug the device's power back. "
			"Waiting for the device...\n");
	while(1){
		my_write(port_handle, buf, sizeof(buf), (unsigned char *)"serial port");
		my_usleep(100000);
		if (check_reply(response, sizeof(response))){
			printf("Got a reply from the device.\n");
			return;
		}
	}
}

/* The handle must be an open file. Prints information about sending
 * and completing the file. */
void send_xmodem_file(unsigned char *filename)
{
	unsigned char buf[1024]; /* Must be exactly 1024 because it's used for
				    xmodem as well. */
	ssize_t readb; /* Number of bytes read */
	int data_handle;

	data_handle=my_open(filename, O_RDONLY, 0);
	printf("Sending data file %s\n", filename);
	init_xmodem();
again:
	readb=my_read(data_handle, buf, sizeof(buf),
			filename);
	if (!readb){
		close_xmodem();
		my_close(data_handle);
		printf("Data file sent.\n");
		return;
	}
	send_xmodem_block(buf, sizeof(buf));
	goto again;
}

unsigned char bootloader_buf[4096]; /* Common for both send_bootloader_translate
                                       and send_bootloader_raw functions. Can
                                       be an arbitrary length */

/* Takes a file in binary format and sends it in the sdb format */
void send_bootloader_translate()
{
	ssize_t readb; /* Number of bytes read */
  unsigned char *ptr;

	printf("Sending the bootloader...\n");
  sdb_init(port_handle);
again:
	readb=my_read(bootloader_handle, bootloader_buf, sizeof(bootloader_buf)
			,(unsigned char *)"the bootloader file");
	if (!readb){
    sdb_finish();
		printf("Bootloader sent.\n");
		return;
	}
  for (ptr=bootloader_buf; readb; readb--)
    sdb_output_char(*ptr++);
	goto again;
}

/* Sends a file as is to the serial port */
void send_bootloader_as_is()
{
	ssize_t readb; /* Number of bytes read */

	printf("Sending the bootloader...\n");
again:
	readb=my_read(bootloader_handle, bootloader_buf, sizeof(bootloader_buf)
			,(unsigned char *)"the bootloader file");
	if (!readb){
		printf("Bootloader sent.\n");
		return;
	}
	my_write(port_handle, bootloader_buf, readb, (unsigned char *)"serial port");
	goto again;
}

void send_bootloader(void)
{
  if (bootloader_is_binary) send_bootloader_translate();
  else send_bootloader_as_is();
}

void send_memory_file(unsigned char *data, unsigned len)
{
	unsigned consume;

	init_xmodem();
	while(len){
		consume=MIN(len, 1024);
		send_xmodem_block(data, consume);
		data+=consume;
		len-=consume;
	}
	close_xmodem();

}

void wait_prompt(void)
{
	const unsigned char req='\n';
	const unsigned char reply='$';
	unsigned cycles=0;
	printf("Waiting for the device prompt...\n");
retry:
	if (cycles>=200){
    if (device_type==TYPE_BARIONET){
      ERR("Do you have a jumper on the 2 outermost pins of the J4 "
          "3-pin connector? 20s timed out while waiting for the device "
          "prompt and that can be caused by this jumper missing.");
    }else{
      ERR("20s timed out while waiting for the device prompt");
    }
  }
	my_usleep(100000);
	if (check_reply(&reply, sizeof(reply))){
		printf("Got the device prompt.\n");
		return;
	}
	my_write(port_handle, &req, sizeof(req), (unsigned char *)"serial port");
	cycles++;
	goto retry;

}

/* Malloc with automatic error */
void *mem_alloc(size_t size)
{
	void *rv;
	if (!size) return NULL;
	rv=malloc(size);
	if (!rv){
		fprintf(stderr, PROGNAME": cannot allocate"
			"%u bytes of memory.\r\n", (unsigned)size);
		exit(-1);
	}
	return rv;
}

/* Sends a command and appends a newline. */
void send_command_nl(unsigned char *string)
{
	const unsigned char nl='\n';
	my_write(port_handle, string, strlen((char *)string)
      , (unsigned char *)"serial port");
	my_write(port_handle, &nl, sizeof(nl)
      , (unsigned char *)"serial port");
}

/* Sends the command to receive the data file and then the data file. Frees
 * the datafiles afterwards. */
void send_data_files(void)
{
	unsigned size;
	unsigned total_size=0;
	unsigned char *ptr=datafiles;

	while (total_size<datafiles_size){
		wait_prompt();
		send_command_nl(device_type?(unsigned char *)"dlbinsf"
        :(unsigned char *)"dlbinpf");
		send_xmodem_file(ptr);
		size=strlen((char *)ptr)+1;
		total_size+=size;
		ptr+=size;
	}
	if (datafiles) free(datafiles); /* We don't need them anymore. */
}	

/* This function must not be called reboot because on MAC there is some
 * system function reboot. */
void reboot_device(void)
{
	wait_prompt();
	printf("Rebooting the device...\n");
	send_command_nl((unsigned char *)(void *)"reboot");
	my_usleep(3000000);
	printf("The device should have been rebooted now.\n");
}

void check_config(void)
{
	if (bootloader_handle<0)
		ERR("the bootloader filename must be specified. Use the -h"
				" flag to get help.\n");
}

off_t my_lseek(int fd, off_t offset, int whence, unsigned char *context)
{
	off_t rv;

again:
	rv=lseek(fd, offset, whence);
	if (rv==(off_t)-1){
		if (errno==EINTR) goto again;
		fprintf(stderr,"can't seek in %s: ",context);
		perror("");
		exit(-1);
	}
	return rv;
}

/* Side effect: seeks to the beginning of the file.
 * Returns file length of the file pointed to by
 * the file descriptor fd. */
off_t filelen(int fd, unsigned char *context)
{
	off_t len;
	len=my_lseek(fd, 0, SEEK_END, context);
	my_lseek(fd, 0, SEEK_SET, context);
	return len;
}

/* Returns the length of the original file. Space allocated is
 * file_length+prepend long. The file size is aligned on 2-byte boundary!
 * The returned length. The appendage is both before and after the file
 * and on both sides has the same length.
 *
 * fd is allowed to be <0. In this case the file is omitted. */
unsigned file2mem(int fd, unsigned char **data,
		unsigned append, unsigned char *context)
{
	off_t len;
	if (fd>=0){
		len=filelen(fd, context);
	}else len=0;
	*data=mem_alloc(len+(len&1)+(append<<1));
	if (fd>=0) my_read(fd, (*data)+append, len, context);
	if (len&1) (*data)[len]=0;
	return len+(len&1);
}

#define RST1_LEN 36 /* Including trailing zero */
void write_rst1(unsigned char *where, unsigned long lina, unsigned long len)
{
	if (snprintf((char *)where,RST1_LEN,
        "RST1 Seg:%04lX Off:%04lX Len:%08lX",
				lina>>8, lina&0xff, len)+1
		!=RST1_LEN) ERR("internal error: rst1 length doesn't"
			" match\n");
}

void write_rst1_seg_off(unsigned char *where, unsigned seg, unsigned off, unsigned long len)
{
	if (snprintf((char *)where,RST1_LEN,
        "RST1 Seg:%04X Off:%04X Len:%08lX",
				seg, off, len)+1
		!=RST1_LEN) ERR("internal error: rst1 length doesn't"
			" match\n");
}

/* If handle is <0, nothing is read. if handle<0, context may
 * be NULL. */
void flash(unsigned long lina, int handle, unsigned char *context)
{
	unsigned len;
	unsigned char *data;

	wait_prompt();
 	len=file2mem(handle, &data, RST1_LEN, context);
	write_rst1(data, lina, len);
	write_rst1(data+RST1_LEN+len, 0, 0); /* Terminating command */
	send_command_nl((unsigned char *)"dlbinpf");
	send_memory_file(data, len+(RST1_LEN<<1));
	free(data);
}

/* data must be allocated to len+(RST1_LEN<<1), len must be even, data must start at offset RST1_LEN */
void flash_data(unsigned long lina, unsigned char * data, int len)
{
	wait_prompt();
	write_rst1(data, lina, len);
	write_rst1(data+RST1_LEN+len, 0, 0); /* Terminating command */
	send_command_nl((unsigned char *)"dlbinpf");
	send_memory_file(data, len+(RST1_LEN<<1));
	memset(data,0,len+(RST1_LEN<<1));
	free(data);
}

/* data must be allocated to len+(RST1_LEN<<1), len must be even, data must start at offset RST1_LEN */
void flash_seg_off(unsigned seg,unsigned off, unsigned char * data, int len)
{
	wait_prompt();
	write_rst1_seg_off(data, seg,off, len);
	write_rst1(data+RST1_LEN+len, 0, 0); /* Terminating command */
	send_command_nl((unsigned char *)"dlbinpf");
	send_memory_file(data, len+(RST1_LEN<<1));
	free(data);
}

/* Do not include the newline in the command when calling this function. */
void simple_command(unsigned char *cmd, unsigned seconds)
{
	unsigned char c;

	wait_prompt();
	printf("Executing command %s...\n", cmd);
	send_command_nl(cmd);
spurious_select:
	if (wait_for_available_data(seconds)){
			printf("Didn't get prompt after %s"
				" command. %s probably"
				" failed\n", cmd, cmd);
	}else{
		if (!my_read(port_handle, &c, sizeof(c), (unsigned char *)"serial port"))
			goto spurious_select;
		/* see man select, BUGS */
		if (c!='$'){
			printf("Warning: got ");
			print_serial_char(c);
			printf(" instead of prompt ($).\n");
			consume_garbage((unsigned char *)"after supposed prompt");
		}else
			printf("%s successful.\n", cmd);
			consume_garbage((unsigned char *)"after prompt");
	}
}

void erase_flash(void)
{
	printf("Erasing the flash...\n");
	simple_command((unsigned char *)"erase_pf",20);
	printf("Flash erased.\n");
}

void do_erase_bootarea(void)
{
}

void write_config(void)
{
	printf("Writing the configuration...\n");
	flash(0xeeee00, config_handle, (unsigned char *)"config file");
	printf("Configuration written.\n");
}

/* reads a key file from keyfile_handle, creates security record and writes it into the EEPROM */
void write_config_key(void)
{
	unsigned char *data;
	int len;

#define KEY_SIZE 16
#define KEY_PLAINTEXT_FLAG 0
#define SECURITY_AREA_OFFSET 1750-8		/* offset of the security area in EEPROM - relative to the start of Setup */
#define SECURITY_AREA_SIZE 50			/* size of the security area */
#define KEY_OFFSET 34				/* offset of the key in the security area */
#define KEY_SCRAMBLED_OFFSET 33			/* offset of the "key scrambled" byte within the security area */

	printf("Writing security information...\n");
	data=mem_alloc(SECURITY_AREA_SIZE+2*RST1_LEN);
	memset(data+RST1_LEN,0,SECURITY_AREA_SIZE);
	len=filelen(keyfile_handle, (unsigned char *)"key file");

	if (len!=KEY_SIZE) {
		fprintf(stderr, PROGNAME": this is not a key file\n");
		exit(-1);
	}

	data[RST1_LEN+KEY_SCRAMBLED_OFFSET]=KEY_PLAINTEXT_FLAG;
	my_read(keyfile_handle, data+RST1_LEN+KEY_OFFSET, len , (unsigned char *)"key file");
	close(keyfile_handle);
	flash_seg_off(0xeeee,SECURITY_AREA_OFFSET, data, SECURITY_AREA_SIZE);
	printf("Security information written.\n");
}

void erase_eeprom(void)
{
	printf("Erasing the EEPROM...\n");
	simple_command((unsigned char *)"erase_ee",10);
	printf("EEPROM erased.\n");
}

/* Erases the bootloader area and then writes the bootloader into the flash. */
void flash_bootloader(void)
{
  int handle;

  handle=my_open(flash_bootloader_filename, O_RDONLY, 0);
	printf("Writing the bootloader from %s into flash...\n",
      flash_bootloader_filename);
	simple_command((unsigned char *)"erase_pf FF00",10);
  flash(0xff0000, handle, flash_bootloader_filename);
  my_close(handle);
	printf("Bootloader flashed.\n");
}

/* Sends the dlraw sf 310 command. This is good for loading the webpage
 * (the .cob file) into the Barionet. */
void send_dlraw(void)
{
	printf("Sending %s into Barionet webpage area...\n",
			dlraw_filename);
	wait_prompt();
	send_command_nl((unsigned char *)"dlraw sf 310");
	send_xmodem_file(dlraw_filename);
	printf("Data file sent.\n");
}

/* Acts as a flasher over the serial port. The parameters are
 * parsed by getopt. */
void act_as_flasher(int argc, char **argv)
{
	parse_args(argc, argv);
	check_config();
	open_serial();
	get_initial_response();
	send_bootloader(); /* Send the bootloader */
	if (speed!=B115200&&device_type!=TYPE_BARIONET){
		/* After the bootloader is loaded, the speed is always
		 * 115200. Except for Barionet, which keeps the same speed. */
		speed=B115200;
		set_speed();
	}
	if (erase_pf)
		erase_flash();
  if (device_type==TYPE_DEFAULT&&flash_bootloader_filename)
    flash_bootloader();
	send_data_files(); /* If there are no data files, it automatically doesn't
			      do anything ;-) */
	if (dlraw_filename) send_dlraw();
	if (erase_ee)
		erase_eeprom();
	if (keyfile_handle>=0) {
		write_config_key();
	}
	else if (config_handle>=0) {
		write_config();
	}
	reboot_device();
  printf("SUCCESSFUL\n");
}

void emit_rst1(int handle, unsigned segment, unsigned long len)
{
	unsigned char buffer[RST1_LEN];
	write_rst1(buffer, segment<<8, len);
	my_write(handle, buffer, sizeof(buffer), (unsigned char *)"serial port");
}

/* dest and src are filehandles. Copies one file
 * into the other. */
void file2file(int dest, int src, unsigned char *destname,
		unsigned char *srcname)
{
	unsigned char buf[4096];
	ssize_t consumed;

	while((consumed=my_read(src, buf, sizeof(buf), srcname)))
		my_write(dest, buf, consumed, destname);
	
}

/* Acts as a compound file generator. The parameters
 * are governed by a fixed scheme. argc must be at least
 * 3 on entry into this function. */
void act_as_generator(int argc, char **argv)
{
	int ofd; /* Output file descriptor */
	int ifd; /* Input file descriptor */
	unsigned long len;
	int i;
	unsigned char zero=0;

	if (!strcmp(argv[2],"-f")){
		/* Erase flash specified, this turns off generation of
		 * RST1 Seg:FFFF Off:0000 Len:00000000 */
		erase_pf=1;
		argc--;
		argv++;
	}
	if (argc<3)
		ERR("Too few arguments for -g");
	ofd=my_open((unsigned char *)argv[2],O_CREAT|O_WRONLY|O_TRUNC, 0);
	if (!erase_pf) emit_rst1(ofd, 0xFFFF, 0);
	for (i=3; i+1<argc; i+=2){
		ifd=my_open((unsigned char *)argv[i], O_RDONLY, 0);
		len=filelen(ifd, (unsigned char *)argv[i]);
		emit_rst1(ofd, strtoul(argv[i+1],NULL,0)
				,len+(len&1));
		file2file(ofd, ifd, (unsigned char *)argv[2],
				(unsigned char *)argv[i+1]);
		if (len&1) my_write(ofd, &zero, 1, (unsigned char *)argv[2]);
		my_close(ifd);
	}
	emit_rst1(ofd, 0, 0);
	my_close(ofd);
}

int main (int argc, char **argv)
{
	if (argc>=3&&!strcmp(argv[1],"-g"))
		act_as_generator(argc, argv);
	else
		act_as_flasher(argc, argv);
	return 0;
}
