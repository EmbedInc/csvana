{   Graphics events handling.
}
module csvana_events;
define csvana_events_setup;
define csvana_events_thread;
%include 'csvana.ins.pas';

const
  key_mleft_k = 1;                     {our left mouse key ID}
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
{
*   Request the events we will use.
}
  rend_set.event_req_close^ (true);    {device closed, user requested close}
  rend_set.event_req_resize^ (true);   {drawing area size changed}
  rend_set.event_req_wiped_resize^ (true); {wiped out due to resize, now drawable}
  rend_set.event_req_wiped_rect^ (true); {rectange of pixels got wiped out}
  rend_set.event_req_scroll^ (true);   {scroll wheel motion}
  rend_set.event_req_pnt^ (true);      {pointer motion}

  rend_set.event_req_key_on^ (         {left mouse button}
    rend_get.key_sp^(rend_key_sp_pointer_k, 1),
    key_mleft_k);
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
  next_event, done_event;

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
      end
    ;
  evwait := ev.ev_type = rend_ev_none_k; {no event immediately available ?}
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

rend_ev_key_k: begin                   {a user key changed state}
      if not ev.key.down then goto done_event; {ignore key releases here}
      case ev.key.key_p^.id_user of    {which of our keys is it ?}
key_mleft_k: begin                     {left mouse key}
          csvana_drag_cursor (ev.key, pend_redraw); {drag the independent data value cursor}
          end;
        end;                           {end of our key ID cases}
      end;

rend_ev_scrollv_k: begin               {vertical scroll wheel motion}
      if ev.scrollv.n = 0 then goto done_event; {no net motion ?}
      csvana_zoom (ev.scrollv.n);      {update state to do the zoom}
      pend_resize := true;
      pend_redraw := true;
      end;

    end;                               {end of event type cases}
done_event:                            {done handling the current event in EV}
  goto next_event;                     {done processing this event, back for next}
  end;
