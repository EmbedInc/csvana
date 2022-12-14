{   Drawing thread.
}
module csvana_draw_thread;
define csvana_draw_thread;
define csvana_do_resize;
define csvana_do_redraw;
%include 'csvana.ins.pas';
{
********************************************************************************
*
*   Local subroutine CSVANA_DRAW_THREAD
*
*   This routine is run in a separate thread.  It responds to request to resize
*   to the drawing area and to refresh the drawing area.
}
procedure csvana_draw_thread (         {thread to do drawing in background}
  in      arg: sys_int_adr_t);         {arbitrary argument, unused}
  val_param;

var
  stat: sys_err_t;                     {completion status}

begin
  while true do begin                  {back here until nothing to do}
    if do_resize then begin            {pending resize ?}
      do_resize := false;              {clear the event condition}
      csvana_draw_resize;              {do the resize}
      next;                            {back to check for any pending tasks again}
      end;
    if do_redraw then begin            {pending redraw ?}
      do_redraw := false;              {clear the event condition}
      csvana_draw;                     {do the redraw}
      next;                            {back to check for any pending tasks again}
      end;
    sys_event_wait (evdrtask, stat);   {wait for new task to perform}
    end;                               {back again to check for something to do}
  end;
{
********************************************************************************
*
*   Subroutine CSVANA_DO_RESIZE
*
*   Cause the drawing thread to resize to the current display device.
}
procedure csvana_do_resize;            {cause drawing thread to resize to display}
  val_param;

begin
  do_resize := true;                   {indicate resize pending}
  sys_event_notify_bool (evdrtask);    {indicate pending drawing task to perform}
  end;
{
********************************************************************************
*
*   Subroutine CSVANA_DO_REDRAW
*
*   Cause the drawing thread to refresh the current display.
}
procedure csvana_do_redraw;            {cause drawing thread to redraw display}
  val_param;

begin
  do_redraw := true;                   {indicate redraw pending}
  sys_event_notify_bool (evdrtask);    {indicate pending drawing task to perform}
  end;
