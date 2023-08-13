{   Drawing thread.
}
module anashow_draw_thread;
define anashow_draw_thread;
define anashow_do_resize;
define anashow_do_redraw;
define anashow_do_tactiv;
%include 'anashow.ins.pas';
{
********************************************************************************
*
*   Local subroutine ANASHOW_DRAW_THREAD
*
*   This routine is run in a separate thread.  It responds to request to resize
*   to the drawing area and to refresh the drawing area.
}
procedure anashow_draw_thread (        {thread to do drawing in background}
  in      arg: sys_int_adr_t);         {arbitrary argument, unused}
  val_param;

var
  stat: sys_err_t;                     {completion status}

begin
  while true do begin                  {back here until nothing to do}
    if do_resize then begin            {pending resize ?}
      do_resize := false;              {clear the event condition}
      anashow_draw_resize;             {do the resize}
      next;                            {back to check for any pending tasks again}
      end;
    if do_redraw then begin            {pending redraw ?}
      do_redraw := false;              {clear the event condition}
      anashow_draw;                    {do the redraw}
      next;                            {back to check for any pending tasks again}
      end;
    if do_tactiv then begin            {pending activity indicator update ?}
      do_tactiv := false;              {clear the event condition}
      anashow_draw_tactiv;             {update the activity indicator}
      next;
      end;
    sys_event_wait (evdrtask, stat);   {wait for new task to perform}
    end;                               {back again to check for something to do}
  end;
{
********************************************************************************
*
*   Subroutine ANASHOW_DO_RESIZE
*
*   Cause the drawing thread to resize to the current display device.
}
procedure anashow_do_resize;           {cause drawing thread to resize to display}
  val_param;

begin
  do_resize := true;                   {indicate resize pending}
  sys_event_notify_bool (evdrtask);    {indicate pending drawing task to perform}
  end;
{
********************************************************************************
*
*   Subroutine ANASHOW_DO_REDRAW
*
*   Cause the drawing thread to refresh the current display.
}
procedure anashow_do_redraw;           {cause drawing thread to redraw display}
  val_param;

begin
  do_redraw := true;                   {indicate redraw pending}
  sys_event_notify_bool (evdrtask);    {indicate pending drawing task to perform}
  end;
{
********************************************************************************
*
*   Subroutine ANASHOW_DO_TACTIV
*
*   Cause the activity indicator to be updated to the current state.  The
*   activity indicator is drawn when TACTIV is within the current displayed data
*   time range, and erased otherwise.
}
procedure anashow_do_tactiv;           {cause activity indicator to be redrawn}
  val_param;

begin
  do_tactiv := true;                   {indicate activity redraw pending}
  sys_event_notify_bool (evdrtask);    {indicate pending drawing task to perform}
  end;
