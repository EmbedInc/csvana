{   Graphics events handling.
}
module anashow_events;
define anashow_events_setup;
define anashow_events_thread;
%include 'anashow.ins.pas';

const
  key_drag_k = 1;                      {key ID for dragging a cursor}
  key_zoomin_k = 2;                    {key ID for zoom in}
  key_zoomout_k = 3;                   {key ID for zoom out}
  key_pan_k = 4;                       {key ID to pan data along X axis}
  key_cursdong_k = 5;                  {set dongle record from cursor position}
  key_dongnext_k = 6;                  {drive dongle with next sequential record}
  key_runto_k = 7;                     {drive dongle from curr position to cursor}
  key_simpos_k = 8;                    {set sim pos to curs, SHIFT to data start}
  key_simrun_k = 9;                    {step sim to next rec, SHIFT to cursor}
{
********************************************************************************
*
*   Subroutine ANASHOW_EVENTS_SETUP
*
*   Set up the RENDlib events they way they will be used here.
}
procedure anashow_events_setup;
  val_param;

begin
{
*   Request the events we will use.
}
  rend_set.event_req_close^ (true);    {device closed, user requested close}
  rend_set.event_req_wiped_resize^ (true); {wiped out due to resize, now drawable}
  rend_set.event_req_wiped_rect^ (true); {rectange of pixels got wiped out}
  rend_set.event_req_scroll^ (true);   {scroll wheel motion}
  rend_set.event_req_pnt^ (true);      {pointer motion}

  rend_set.event_req_key_on^ (         {left mouse button}
    rend_get.key_sp^(rend_key_sp_pointer_k, 1),
    key_drag_k);
  rend_set.event_req_key_on^ (         {center mouse button}
    rend_get.key_sp^(rend_key_sp_pointer_k, 2),
    key_pan_k);
  rend_set.event_req_key_on^ (         {Page Up button}
    rend_get.key_sp^(rend_key_sp_pageup_k, 0),
    key_zoomin_k);
  rend_set.event_req_key_on^ (         {Page Down button}
    rend_get.key_sp^(rend_key_sp_pagedn_k, 0),
    key_zoomout_k);

  rend_set.event_req_key_on^ (         {dongle data record from cursor position}
    rend_get.key_sp^(rend_key_sp_arrow_down_k, 0),
    key_cursdong_k);
  rend_set.event_req_key_on^ (         {dongle data record to next sequential rec}
    rend_get.key_sp^(rend_key_sp_arrow_right_k, 0),
    key_dongnext_k);
  rend_set.event_req_key_on^ (         {drive dongle from curr pos to cursor}
    rend_get.key_sp^(rend_key_sp_arrow_up_k, 0),
    key_runto_k);

  rend_set.event_req_key_on^ (         {set sim position}
    rend_get.key_sp^(rend_key_sp_func_k, 1),
    key_simpos_k);
  rend_set.event_req_key_on^ (         {step or run sim}
    rend_get.key_sp^(rend_key_sp_func_k, 2),
    key_simrun_k);
  end;
{
********************************************************************************
*
*   Subroutine ANASHOW_EVENTS_THREAD (ARG)
*
*   This subroutine is run from a separate thread.  It handles graphics events
*   in an infinite loop.
}
procedure anashow_events_thread (      {thread to handle graphics events}
  in      arg: sys_int_adr_t);         {arbitrary argument, unused}
  val_param;

var
  ev: rend_event_t;                    {last RENDlib event received}
  evwait: boolean;                     {wait on next event}
  pend_resize: boolean;                {resize is pending}
  pend_redraw: boolean;                {redraw is pending}
  px, py: sys_int_machine_t;           {pointer coordinates, 2DIMI space}
  x, y: real;                          {scratch 2D coordinate}
  d: double;                           {scratch data value}
  rec_p: csvana_rec_p_t;               {scratch pointer to data record}
  mask: db25_pinmask_t;                {scratch pins mask}

label
  next_event, done_event;

begin
  evwait := true;                      {wait for next event}
  pend_resize := false;                {init to no resize pending}
  pend_redraw := false;                {init to no redraw pending}
  px := 0;                             {init pointer coordinates}
  py := 0;

next_event:                            {back here to get the next event}
  if evwait
    then begin                         {no event is immediately available}
      if pend_resize then begin        {handle pending resize}
        pend_resize := false;
        anashow_do_resize;
        end;
      if pend_redraw then begin        {handle pending redraw}
        pend_redraw := false;
        anashow_do_redraw;
        end;
      rend_event_get (ev);             {get next event, wait as long as it takes}
      end
    else begin                         {get immediate event}
      rend_event_get_nowait (ev);      {get what is available now, even if none}
      end
    ;
  evwait := ev.ev_type = rend_ev_none_k; {no event immediately available ?}
  (* rend_event_show (ev); *)
  case ev.ev_type of                   {what kind of event is it ?}

rend_ev_close_k,                       {drawing device got closed, RENDlib still open}
rend_ev_close_user_k: begin            {user wants to close the drawing device}
      util_mem_context_del (szmem_p);  {delete mem context for current config}
      rend_end;
      writeln;                         {finish any partially written line}
      sys_exit;                        {end the program}
      end;

rend_ev_wiped_resize_k: begin          {pixels wiped out due to size change}
      pend_resize := true;             {indicate resize is pending}
      sys_wait (0.050);                {time for related events to show up}
      end;

rend_ev_wiped_rect_k: begin            {rectangle of pixels got wiped out}
      pend_redraw := true;             {indicate redraw is pending}
      sys_wait (0.050);                {time for related events to show up}
      end;

rend_ev_pnt_move_k: begin              {the pointer moved}
      px := ev.pnt_move.x;             {update our saved pointer location}
      py := ev.pnt_move.y;
      end;

rend_ev_scrollv_k: begin               {vertical scroll wheel motion}
      if ev.scrollv.n = 0 then goto done_event; {no net motion ?}
      pix2d (px, py, x, y);            {make pointer location in 2D space}
      x := max(datlx, min(datrx, x));  {clip to displayed data range}
      d := datxt (x);                  {make data value to zoom about}
      anashow_zoom (ev.scrollv.n, d);  {do the zoom}
      pend_resize := true;             {need to re-adjust to drawing area size}
      end;

rend_ev_key_k: begin                   {a user key changed state}
      px := ev.key.x;                  {update pointer location}
      py := ev.key.y;
      if not ev.key.down then goto done_event; {ignore key releases here}
      case ev.key.key_p^.id_user of    {which of our keys is it ?}
{
********************
*
*   Key: Drag a data value.
}
key_drag_k: begin
  csvana_drag_cursor (ev.key, pend_redraw); {drag the independent data value cursor}
  end;
{
********************
*
*   Key: Pan the display horizontally.
}
key_pan_k: begin
  anashow_pan (ev.key, pend_resize);   {pan in X}
  end;
{
********************
*
*   Key: Zoom in.
}
key_zoomin_k: begin
  if rend_key_mod_shift_k in ev.key.modk then begin {zoom in to meas range ?}
    d := (meas2 - meas1) * minmeas;    {room to leave either side}
    datt1 := meas1 - d;                {set data range to display}
    datt2 := meas2 + d;
    anashow_datt_upd;                  {sanitize and update derived values}
    pend_resize := true;
    goto done_event;
    end;
  anashow_zoom (1, curs);              {zoom in about the data cursor}
  pend_resize := true;                 {need to re-adjust to drawing area size}
  end;
{
********************
*
*   Key: Zoom out.
}
key_zoomout_k: begin
  if rend_key_mod_shift_k in ev.key.modk then begin {zoom out to all data ?}
    datt1 := csv_p^.rec_p^.time;
    datt2 := csv_p^.rec_last_p^.time;
    anashow_datt_upd;                  {sanitize and update derived values}
    pend_resize := true;
    goto done_event;
    end;
  anashow_zoom (-1, curs);             {zoom out about the data cursor}
  pend_resize := true;                 {need to re-adjust to drawing area size}
  end;
{
********************
*
*   Key: Set dongle data record from cursor.
}
key_cursdong_k: begin
  if rend_key_mod_shift_k in ev.key.modk then begin {go to first data record ?}
    if csv_p = nil then goto done_event; {no data records at all ?}
    dong_conn;                         {make sure connected to the dongle}
    dong_rec_set (csv_p^.rec_p);       {drive dongle from first data record}
    pend_redraw := true;
    goto done_event;
    end;
  dong_conn;                           {make sure connected to the dongle}
  dong_rec_curs;                       {set dongle record from cursor position}
  pend_redraw := true;
  end;
{
********************
*
*   Key: Set dongle drive to the next data record.
}
key_dongnext_k: begin
  if dongrec_p = nil                   {no current record to start from ?}
    then goto done_event;
  dong_rec_next;                       {to next record}
  pend_redraw := true;
  end;
{
********************
*
*   Key: Run dongle from current position to the cursor.
}
key_runto_k: begin
  rec_p := csvana_datt_rec(curs);      {get pointer to record at cursor}
  if rec_p = nil                       {no target record to end on ?}
    then goto done_event;
  case dong_run(rec_p, [], mask) of
runend_stoprec_k, runend_diff_k, runend_end_k: begin {actually ran ?}
      pend_redraw := true;
      end;
    end;
  end;
{
********************
*
*   Key: Set dongle simulation position within data.
}
key_simpos_k: begin
  if csv_p = nil then goto done_event; {ignore if no data records}
{
*   Shift: Set to first data record.
}
  if rend_key_mod_shift_k in ev.key.modk then begin {SHIFT active ?}
    sim_rec (csv_p^.rec_p);            {set sim to first data record}
    pend_redraw := true;
    goto done_event;
    end;
{
*   Normal: Set to data record indicated by the cursor.
}
  sim_rec_curs;                        {set sim to data record at cursor, if any}
  pend_redraw := true;
  end;
{
********************
*
*   Key: Run the simulation.
}
key_simrun_k: begin
  if simrec_p = nil then goto done_event; {no position set to start from ?}
{
*   Shift: Run to cursor.
}
  if rend_key_mod_shift_k in ev.key.modk then begin {SHIFT active ?}
    rec_p := csvana_datt_rec(curs);    {get data record at cursor}
    if rec_p = nil then goto done_event; {no fixed ending record ?}
    case sim_run(rec_p) of             {run sim, get stop reason}
runend_stoprec_k, runend_diff_k, runend_end_k: begin {actually ran ?}
        pend_redraw := true;
        end;
      end;
    goto done_event;
    end;
{
*   Normal: Step the simulation one data record.
}
  sim_rec_next;                        {advance sim to next data record}
  pend_redraw := true;
  end;
{
********************
*
*   Done with which-key cases.
}
        end;                           {end of our key ID cases}
      end;                             {end of key changed event}

    end;                               {end of event type cases}
done_event:                            {done handling the current event in EV}
  goto next_event;                     {done processing this event, back for next}
  end;
