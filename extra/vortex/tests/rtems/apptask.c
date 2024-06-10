#include "system.h"

#include <stdio.h>
#include <stdlib.h>

#include <rtems.h>
#include <rtems/bspIo.h>
#include <rtems/libcsupport.h>
#include <stdint.h>

#include "main.h"

#ifndef ARGV
#define ARGV {"rtems_app"};
#define ARGC 1
#endif


rtems_task Application_task(
  rtems_task_argument argument
)
{
  rtems_id          tid;
  rtems_status_code status;
  unsigned int      a = (unsigned int) argument;

  status = rtems_task_ident( RTEMS_WHO_AM_I, RTEMS_SEARCH_ALL_NODES, &tid );
  char* argv[] = ARGV;
  int argc = ARGC;
  main(argc, argv);
  exit( 0 );
}
