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
#ifndef __XMODEM_H_
#define __XMODEM_H_

#define SOH 1
#define STX 2
#define EOT 4
#define ACK 6
#define NAK 21
#define CAN 24

/* Call this before sending the first xmodem block */
extern void init_xmodem(void);
extern void send_xmodem_block(unsigned char *block, unsigned len);
extern void close_xmodem(void);
extern void print_serial_char(unsigned char c);
extern int wait_for_available_data(double timeout);
extern int consume_garbage(unsigned char *when);

#endif /* __XMODEM_H_ */
