/*
 * Simple RTEMS configuration
 */

#define CONFIGURE_APPLICATION_NEEDS_CLOCK_DRIVER
#define CONFIGURE_APPLICATION_NEEDS_CONSOLE_DRIVER

#define CONFIGURE_UNLIMITED_OBJECTS
#define CONFIGURE_UNIFIED_WORK_AREAS

#define CONFIGURE_RTEMS_INIT_TASKS_TABLE

#define CONFIGURE_INIT

#define CONFIGURE_MAXIMUM_PROCESSORS 4

#include <rtems/confdefs.h>

#include "system.h"

// openmp support
#include <omp.h>

void __attribute__((__constructor__(1000))) config_libgomp(void)
{
    setenv("OMP_DISPLAY_ENV", "VERBOSE", 1);
    setenv("GOMP_SPINCOUNT", "30000", 1);
    setenv("GOMP_DEBUG", "1", 1);
    setenv("OMP_NUM_THREADS", "4",1);
}

#include <stdio.h>

/* forward declarations to avoid warnings */
rtems_task Init(rtems_task_argument argument);

const char rtems_test_name[] = "SAMPLE SINGLE PROCESSOR APPLICATION";

#define ARGUMENT 0

rtems_task Init(
  rtems_task_argument argument
)
{
  rtems_name        task_name;
  rtems_id          tid;
  rtems_status_code status;

  printf( "Creating and starting an application task\n" );

  task_name = rtems_build_name( 'T', 'A', '1', ' ' );

  status = rtems_task_create( task_name, 1, RTEMS_MINIMUM_STACK_SIZE,
             RTEMS_INTERRUPT_LEVEL(0), RTEMS_DEFAULT_ATTRIBUTES, &tid );

  status = rtems_task_start( tid, Application_task, ARGUMENT );

  rtems_task_exit();
}
