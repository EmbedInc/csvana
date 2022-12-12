{   Drawing thread.
}
module csvana_draw_thread;
define csvana_draw_thread;
%include 'csvana.ins.pas';
{
********************************************************************************
*
*   Local subroutine CSVANA_DRAW_THREAD
*
*   This routine is run in a separate thread.  It draws the data, then services
*   graphics events until the drawing device is closed or the user requests it
*   to be closed.
}
procedure csvana_draw_thread (         {thread to do drawing in background}
  in      arg: sys_int_adr_t);         {arbitrary argument, unused}
  val_param;

var
  ev: rend_event_t;                    {last RENDlib event received}
  evwait: boolean;                     {wait on next event}
  do_resize: boolean;                  {update to resize pending}
  do_redraw: boolean;                  {redraw pending}

label
  resize, redraw, next_event;

begin
resize:                                {reconfigure to current drawing area size}
  do_resize := false;                  {clear pending update to new size}
  csvana_draw_resize;                  {update drawing state to new draw area size}

redraw:
  do_redraw := false;                  {clear pending redraw required}
  csvana_draw;                         {redraw whole display with current parameters}

  rend_set.enter_level^ (0);           {make sure to be out of graphics mode}
  evwait := true;                      {wait for next event}

next_event:                            {back here to get the next event}
  if evwait
    then begin                         {wait for next event}
      rend_event_get (ev);             {get next event, wait as long as it takes}
      end
    else begin                         {get immediate event}
      rend_event_get_nowait (ev);      {get what is available now, even if none}
      end
    ;
  case ev.ev_type of                   {what kind of event is it ?}

rend_ev_none_k: begin                  {no event is immediately available}
      if do_resize then goto resize;   {go do any pending service}
      if do_redraw then goto redraw;
      evwait := true;                  {no action pending, wait indefinitely for next event}
      end;

rend_ev_close_k,                       {drawing device got closed, RENDlib still open}
rend_ev_close_user_k: begin            {user wants to close the drawing device}
      util_mem_context_del (szmem_p);  {delete mem context for current config}
      rend_end;
      writeln;                         {finish any partially written line}
      sys_exit;                        {end the program}
      end;

rend_ev_resize_k,                      {drawing area size changed}
rend_ev_wiped_resize_k: begin          {pixels wiped out due to size change}
      do_resize := true;               {flag pending adjust to new size}
      evwait := false;                 {process only immediate events}
      sys_wait (0.050);                {time for related events to show up}
      end;

rend_ev_wiped_rect_k: begin            {rectangle of pixels got wiped out}
      do_redraw := true;               {flag pending redraw}
      evwait := false;                 {process only immediate events}
      sys_wait (0.050);                {time for related events to show up}
      end;

    end;                               {end of event type cases}
  goto next_event;                     {done processing this event, back for next}
  end;
