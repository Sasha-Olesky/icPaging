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
#include <stdio.h>
#include "main.h"

unsigned shift;
unsigned sum;
int handle;

unsigned char buf[4096];
unsigned buf_chars;

/* Writes the buf into the serial port and sets it to empty */
void flush_buf(void)
{
  my_write(handle, buf, buf_chars, (unsigned char *)"serial port");
  buf_chars=0;
}

/* Cached write of a char into the serial port */
void char2serial(unsigned char c)
{
  if (buf_chars>=sizeof(buf)) flush_buf();
  buf[buf_chars++]=c;
}

void output(unsigned char c)
{
  if (c<0x80){
    if (c<0x7B){
      if (c<0x20){
        /* 00 - 1F */
        char2serial(0x7D);
        char2serial(c+0x20);
      }else{
        /* 20 - 7A */
        char2serial(c);
      }
    }else{
      /* 7B - 7F */
      char2serial(0x7E);
      char2serial(c);
    }
  }else{
    if (c<0xA0)
    {
      /* 80 - 9F */
      char2serial(0x7C);
      char2serial(c-0x60);
    }else{
      /*A0 - FF */
      char2serial(0x7B);
      char2serial(c-0x80);
    }
  }
}

void sdb_init(unsigned char port_handle)
{
  buf_chars=0;
  sum=0;
  shift=0;
  handle=port_handle;
  char2serial(0x7F);
}

void sdb_output_char(unsigned char c)
{
  output(c);
  sum-=(c<<shift);
  shift^=8;
}

void sdb_finish(void)
{
  if (shift) sdb_output_char(0xff); /* Padding */
  output(sum&0xff); /* Sum LSB */
  output((sum>>8)&0xff); /* Sum MSB */
  char2serial(0x7F);
  flush_buf();
}
