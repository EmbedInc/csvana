{   Graphics events handling.
}
module csvana_events;
define csvana_events_setup;
define csvana_events_thread;
%include 'csvana.ins.pas';
{
********************************************************************************
*
*   Subroutine CSVANA_EVENTS_SETUP
*
*   Set up the RENDlib events they way they will be used here.
}
procedure csvana_events_setup;
  val_param;

begin
  rend_set.event_req_close^ (true);
  rend_set.event_req_resize^ (true);
  rend_set.event_req_wiped_resize^ (true);
  rend_set.event_req_wiped_rect^ (true);
  end;
{
********************************************************************************
*
*   Subroutine CSVANA_EVENTS_THREAD (ARG)
*
*   This subroutine is run from a separate thread.  It handles graphics events
*   in an infinite loop.
}
procedure csvana_events_thread (       {thread to handle graphics events}
  in      arg: sys_int_adr_t);         {arbitrary argument, unused}
  val_param;

var
  ev: rend_event_t;                    {last RENDlib event received}
  evwait: boolean;                     {wait on next event}
  pend_resize: boolean;                {resize is pending}
  pend_redraw: boolean;                {redraw is pending}

label
  next_event;

begin
  evwait := true;                      {wait for next event}
  pend_resize := false;                {init to no resize pending}
  pend_redraw := false;                {init to no redraw pending}

next_event:                            {back here to get the next event}
  if evwait
    then begin                         {no event is immediately available}
      if pend_resize then begin        {handle pending resize}
        pend_resize := false;
        csvana_do_resize;
        end;
      if pend_redraw then begin        {handle pending redraw}
        pend_redraw := false;
        csvana_do_redraw;
        end;
      rend_event_get (ev);             {get next event, wait as long as it takes}
      end
    else begin                         {get immediate event}
      rend_event_get_nowait (ev);      {get what is available now, even if none}
      evwait := ev.ev_type = rend_ev_none_k; {no event immediately available ?}
      end
    ;
  case ev.ev_type of                   {what kind of event is it ?}

rend_ev_close_k,                       {drawing device got closed, RENDlib still open}
rend_ev_close_user_k: begin            {user wants to close the drawing device}
      util_mem_context_del (szmem_p);  {delete mem context for current config}
      rend_end;
      writeln;                         {finish any partially written line}
      sys_exit;                        {end the program}
      end;

rend_ev_resize_k: begin                {drawing area size changed}
      pend_resize := true;             {indicate resize is pending}
      sys_wait (0.050);                {time for related events to show up}
      end;

rend_ev_wiped_resize_k: begin          {pixels wiped out due to size change}
      pend_resize := true;             {indicate resize is pending}
      pend_redraw := true;             {indicate redraw is pending}
      sys_wait (0.050);                {time for related events to show up}
      end;

rend_ev_wiped_rect_k: begin            {rectangle of pixels got wiped out}
      pend_redraw := true;             {indicate redraw is pending}
      sys_wait (0.050);                {time for related events to show up}
      end;

    end;                               {end of event type cases}
  goto next_event;                     {done processing this event, back for next}
  end;
