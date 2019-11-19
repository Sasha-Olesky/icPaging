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
#ifndef __MAIN_H_
#define __MAIN_H_

#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>

#define PROGNAME "load"

#define PROGNAMEE PROGNAME ": "
#define PERR(e) {fprintf(stderr,PROGNAME ": " e ": "); perror(""); exit(-1); }
#define ERR(e) {fprintf(stderr,PROGNAME ": " e "\n"); exit(-1); }
#define MAX(x,y) ((x)>(y)?(x):(y))
#define MIN(x,y) ((x)<(y)?(x):(y))

extern int port_handle;

extern void my_write(int port_handle, const unsigned char *buf, size_t len,
		unsigned char *filename);
extern ssize_t my_read(int fd, unsigned char *buf, size_t len, const
    unsigned char *filename);
extern void *mem_alloc(size_t size);
extern int check_reply(const unsigned char *template, unsigned len);
extern ssize_t my_must_read(int fd, unsigned char * buf, size_t size,
		unsigned char *context);

#endif /* __MAIN_H_ */
