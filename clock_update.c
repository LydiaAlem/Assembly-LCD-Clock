/**
 * @author Lydia Alem
 * @date 02/23/2023
 * @class CSCI 2021: Machine Architecture and Organization.
 * @assignment: Part 01 of Project #2
 * @file clock_update
 */

#include "clock.h"
#include <stdio.h>

/** @function set_tod_from_ports
 *  @param *tod
 *  @return: 0 if successfull, 1 if not successfull
 *
 *  @description: This is a function that reads the time of day from the 
 *                TIME_OF_DAY_PORT global variable. It uses the port value to
 *                calculate the number of seconds from start of day. It also 
 *                uses shifts and masks for this calculation to be efficient. 
 *                After all the calculations have successfully been made, we 
 *                insured that all of the fields from the tod_t struct have
 *                been initalized!
 *
 *  @bug No known bugs.
 */

int set_tod_from_ports(tod_t *tod){
  int time_port = TIME_OF_DAY_PORT;

  if (time_port <= 0 || time_port > 86400 * 16) {
    return 1;
  }

  int seconds = (time_port + 7) >> 4;
  tod->day_secs = seconds;

  int hours = (seconds / 3600);
  tod->time_hours = hours % 12;

  if(tod->time_hours == 0) {
    tod->time_hours = 12;
  }

  int minutes = (seconds / 60) % 60;
  tod->time_mins = minutes;
  
  tod->time_secs = seconds % 60;

  tod->ampm = (hours / 12) + 1;
  
  return 0;
}

/** @function set_display_from_tod
 *  @param tod
 *  @param *display
 *  @return: 0 if successfull, 1 if not successfull
 *
 *  @description: This function accepts a tod and alters the bits in the int 
 *                pointed at by display to reflect how the LCD clock should 
 *                appear. It first checks for valid fields from the 'tod' and 
 *                then does arithmetic computation to find the hours, mins, etc.
 *                I also created an array which contains 10 elements, each being
 *                a bit representation of 1-9 (which can be seen in the write-up).
 *                The array created was used to create the display_pattern using 
 *                indexing and bit shifting.
 *
 *  @bug No known bugs.
 */

int set_display_from_tod(tod_t tod, int *display) {
  /* checking for valid fields from the tod */
  if (tod.time_hours > 12 || tod.time_hours < 1 || tod.time_mins < 0 ||
      tod.time_mins >= 60 || tod.time_secs < 0 || tod.time_secs >= 60 ||
      tod.ampm > 2 || tod.ampm < 1) {
      return 1;
  }
  
  /* using arithmetic calculation to find the time. */
  int hour_ones = tod.time_hours % 10;
  int hour_tens = (tod.time_hours / 10);
  int min_ones = tod.time_mins % 10;
  int min_tens = (tod.time_mins / 10);

  /* an array of bit masks for each digit of the clock */
  int masks[10] = {
    0b1110111, //0
    0b0100100, //1
    0b1011101, //2
    0b1101101, //3
    0b0101110, //4
    0b1101011, //5
    0b1111011, //6
    0b0100101, //7
    0b1111111, //8
    0b1101111, //9
  };

  /* shifting bit patterns to represent  digits and using logical operations to combine them: */
  int display_pattern = 0;
  display_pattern = (masks[min_ones] << 0);
  
  display_pattern |= (masks[min_tens] << 7);
  display_pattern |= (masks[hour_ones] << 14);

  /* The tens digit of the hour is special in that it should be either 1 or blank, so adjustments were made: */
  if(hour_tens != 0){
    display_pattern |= masks[hour_tens] << 21;
  }

  /* set the 28th bit of the state if the time is in the AM or the 29th bit if time is in the PM. */
  display_pattern = tod.ampm == 1 ? display_pattern | 1 << 28 : display_pattern | 1 << 29; 
  *display = display_pattern;
  return 0;
}

/** @function  clock_update
 *  @param NONE
 *  @return: 0 if successfull, 1 if not successfull
 *  
 * @description: Examines the TIME_OF_DAY_PORT global variable to determine hour,
 *               minute, and am/pm.  Sets the global variable CLOCK_DISPLAY_PORT bits
 *               to show the proper time.  If TIME_OF_DAY_PORT appears to be in error
 *               (to large/small) makes no change to CLOCK_DISPLAY_PORT and returns 1
 *               to indicate an error. Otherwise returns 0 to indicate success.
 *
 *  @bug No known bugs.
 */ 
int clock_update(){
  tod_t tod;

  int result = set_tod_from_ports(&tod);
  if (result == 1) {
    /* invalid input, return 1 */
    return 1;
  }

  /* set the clock display from the TOD struct */
  result = set_display_from_tod(tod, &CLOCK_DISPLAY_PORT);
  if(result == 1){
    return 1;
  }
  return 0; 
}
