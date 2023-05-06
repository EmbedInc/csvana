{   Graphics events handling.
}
module csvana_events;
define csvana_events_setup;
define csvana_events_thread;
%include 'csvana.ins.pas';

const
  key_drag_k = 1;                      {key ID for dragging a cursor}
  key_zoomin_k = 2;                    {key ID for zoom in}
  key_zoomout_k = 3;                   {key ID for zoom out}
  key_pan_k = 4;                       {key ID to pan data along X axis}
  key_cursdong_k = 5;                  {set dongle record from cursor position}
  key_dongnext_k = 6;                  {drive dongle with next sequential record}
  key_runto_k = 7;                     {drive dongle from curr position to cursor}
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
  px, py: sys_int_machine_t;           {pointer coordinates, 2DIMI space}
  x, y: real;                          {scratch 2D coordinate}
  d: double;                           {scratch data value}
  rec_p: csvana_rec_p_t;               {scratch pointer to data record}

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
        csvana_do_resize;
        pend_redraw := true;           {cause redraw after size adjustment}
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

rend_ev_key_k: begin                   {a user key changed state}
      px := ev.key.x;                  {update pointer location}
      py := ev.key.y;
      if not ev.key.down then goto done_event; {ignore key releases here}
      case ev.key.key_p^.id_user of    {which of our keys is it ?}
key_drag_k: begin                      {drag a data value}
          csvana_drag_cursor (ev.key, pend_redraw); {drag the independent data value cursor}
          end;
key_pan_k: begin                       {pan the display horizontally}
          csvana_pan (ev.key, pend_resize); {pan in X}
          end;
key_zoomin_k: begin                    {zoom in}
          if rend_key_mod_shift_k in ev.key.modk then begin {zoom in to meas range ?}
            d := (meas2 - meas1) * minmeas; {room to leave either side}
            datt1 := meas1 - d;        {set data range to display}
            datt2 := meas2 + d;
            csvana_datt_upd;           {sanitize and update derived values}
            pend_resize := true;
            goto done_event;
            end;
          csvana_zoom (1, curs);       {zoom in about the data cursor}
          pend_resize := true;         {need to re-adjust to drawing area size}
          end;
key_zoomout_k: begin                   {zoom out}
          if rend_key_mod_shift_k in ev.key.modk then begin {zoom out to all data ?}
            datt1 := csv_p^.rec_p^.time;
            datt2 := csv_p^.rec_last_p^.time;
            csvana_datt_upd;           {sanitize and update derived values}
            pend_resize := true;
            goto done_event;
            end;
          csvana_zoom (-1, curs);      {zoom out about the data cursor}
          pend_resize := true;         {need to re-adjust to drawing area size}
          end;
key_cursdong_k: begin                  {set dongle data record from cursor}
          if rend_key_mod_shift_k in ev.key.modk then begin {go to first data record ?}
            if csv_p = nil then goto done_event; {no data records at all ?}
            dong_conn;                 {make sure connected to the dongle}
            dong_rec_set (csv_p^.rec_p); {drive dongle from first data record}
            pend_redraw := true;
            goto done_event;
            end;
          dong_conn;                   {make sure connected to the dongle}
          dong_rec_curs;               {set dongle record from cursor position}
          pend_redraw := true;
          end;
key_dongnext_k: begin                  {dongle drive to next data record}
          if dongrec_p = nil           {no current record to start from ?}
            then goto done_event;
          dong_rec_next;               {to next record}
          pend_redraw := true;
          end;
key_runto_k: begin                     {run dongle from curr position to cursor}
          if dongrec_p = nil           {no current record to start from ?}
            then goto done_event;
          rec_p := csvana_datt_rec(curs); {get pointer to record at cursor}
          if rec_p = nil               {no target record to end on ?}
            then goto done_event;
          if rec_p^.time < dongrec_p^.time {cursor is before curr dongle record ?}
            then goto done_event;
          while dongrec_p <> rec_p do begin {advance until reach target record}
            dong_rec_next;             {to next record, drive dongle accordingly}
            pend_redraw := true;
            end;                       {back to go to next record}
          end;

        end;                           {end of our key ID cases}
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
      csvana_zoom (ev.scrollv.n, d);   {do the zoom}
      pend_resize := true;             {need to re-adjust to drawing area size}
      end;

    end;                               {end of event type cases}
done_event:                            {done handling the current event in EV}
  goto next_event;                     {done processing this event, back for next}
  end;
