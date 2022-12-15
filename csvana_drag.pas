{   Interactive graphical object dragging.
}
module csvana_drag;
define csvana_drag_cursor;
%include 'csvana.ins.pas';
{
********************************************************************************
*
*   Local subroutine DRAW_LINE (X)
*
*   Draw line showing the indicated 2D X coordinate.
}
procedure draw_line (                  {draw X value indicator line}
  in      x: real);                    {2D X value to show}
  val_param; internal;

begin
  rend_set.cpnt_2d^ (x, 0.0);
  rend_prim.vect_2d^ (x, devh);
  end;
{
********************************************************************************
*
*   Local subroutine NEWX (X, VAL)
*
*   Update the dragged value to the new value X.  VAL is the existing value to
*   update.  The dragged value is only updated to within its valid range.  The
*   drag line is is updated if the value is changed.
}
procedure newx (                       {update to new X value}
  in      x: real;                     {new 2D X to update to}
  in out  val: real);                  {stored value to update}
  val_param; internal;

var
  clx: real;                           {clipped X}

begin
  clx := max(datlx, min(datrx, x));    {make X clipped to its valid range}
  if val <> clx then begin             {value is being changed ?}
    draw_line (val);                   {erase existing line}
    val := clx;                        {update the stored value}
    draw_line (val);                   {draw line showing the new value}
    end;
  end;
{
********************************************************************************
*
*   Subroutine CSVANA_DRAG_CURSOR (KEY, REDRAW)
*
*   Drag one of the data cursors and update their value to the new position.
*   KEY is the key event that started the drag operation.  This is guaranteed
*   to be a key down event.  If the display should be redrawn as a result of the
*   drag operation, then REDRAW is set to TRUE.  Otherwise, REDRAW is unaltered.
}
procedure csvana_drag_cursor (         {drag data value cursor}
  in      key: rend_event_key_t;       {key press event to start drag}
  in out  redraw: boolean);            {will set to TRUE if redraw required}
  val_param;

var
  x, y: real;                          {2D coordinate}
  indid: csvana_ind_k_t;               {ID of selected data value indicator}
  dat_p: ^double;                      {pointer to data value to change by dragging}
  dragv: real;                         {2D X coordinate being dragged}
  ev: rend_event_t;                    {last event read from queue}
  mindm: double;                       {min measurement interval size required}

label
  event, evnotus, done, leave;

begin
  csvana_draw_enter;                   {enter drawing mode}

  pix2d (key.x, key.y, x, y);          {make 2D space click coordinate in X,Y}
  csvana_dataind (x, y, indid);        {get ID of selected indicator}

  case indid of                        {get pointer to data value being dragged}
csvana_ind_st_k: dat_p := addr(meas1);
csvana_ind_en_k: dat_p := addr(meas2);
csvana_ind_curs_k: dat_p := addr(curs);
otherwise
    goto leave;                        {unrecgonized or invalid data indicator ID}
    end;
{
*   The original click point is X,Y in 2D space.  DAT_P is pointing to the data
*   value to adjust by dragging.
}
  redraw := true;                      {a redraw will now be required}

  rend_set.iterp_pixfun^ (rend_iterp_red_k, rend_pixfun_xor_k); {set XOR mode}
  rend_set.iterp_pixfun^ (rend_iterp_grn_k, rend_pixfun_xor_k);
  rend_set.iterp_pixfun^ (rend_iterp_blu_k, rend_pixfun_xor_k);
  rend_set.rgb^ (0.5, 0.5, 0.5);       {color for maximum XOR contrast}

  dragv := max(datlx, min(datrx, x));  {init 2D X value to drag}
  draw_line (dragv);                   {init showing the value being dragged}

event:                                 {back here to get each new event}
  rend_event_get (ev);                 {wait for next event, get it into EV}
  case ev.ev_type of                   {what event is this}

rend_ev_key_k: begin                   {a key changed state}
      if ev.key.down then goto evnotus; {not a key up event ?}
      if ev.key.key_p <> key.key_p     {not our key ?}
        then goto evnotus;
      {
      *   The drag key was released.
      }
      pix2d (                          {find key release point}
        ev.key.x, ev.key.y,            {pixel coordinate}
        x, y);                         {returned 2D coordinate}
      x := max(datlx, min(datrx, x));  {clip to data range}
      dat_p^ := datxt (x);             {update data value being dragged}
      goto done;
      end;

rend_ev_pnt_enter_k,                   {ignore pointer enter/exit events}
rend_ev_pnt_exit_k: ;

rend_ev_pnt_move_k: begin              {pointer moved}
      sys_wait (0.050);                {wait a little while for other events to arrive}
      while true do begin              {get all pointer motion events}
        pix2d (ev.pnt_move.x, ev.pnt_move.y, x, y); {make new coor in 2D space}
        rend_event_get_nowait (ev);    {get immediately available event, if any}
        if ev.ev_type = rend_ev_none_k then exit; {exhausted all events ?}
        if ev.ev_type <> rend_ev_pnt_move_k then begin {not another motion event ?}
          rend_event_push (ev);        {this event is for someone else, put it back}
          exit;
          end;
        end;                           {update state to this latest motion event}
      newx (x, dragv);                 {update dragged value and display}
      end;

otherwise                              {unrecognized or unexpected event}
    goto evnotus;                      {this event is not for us}
    end;                               {end of event type cases}
  goto event;                          {back to get the next event}

evnotus:                               {event isn't for us, push back and end drag}
  rend_event_push (ev);                {put event back onto event queue}

done:                                  {end the drag}
  draw_line (dragv);                   {erase drag line}
  rend_set.iterp_pixfun^ (rend_iterp_red_k, rend_pixfun_insert_k); {restore pixfun}
  rend_set.iterp_pixfun^ (rend_iterp_grn_k, rend_pixfun_insert_k);
  rend_set.iterp_pixfun^ (rend_iterp_blu_k, rend_pixfun_insert_k);

  dat_p^ := datxt(dragv);              {update the data X value that was adjusted}
  mindm := datdt * minmeas;            {make min require meas interval width}
  case indid of                        {which value was adjusted ?}
csvana_ind_st_k: begin                 {start of measuring interval}
      meas2 := max(meas2, meas1 + mindm);
      end;
csvana_ind_en_k: begin                 {end of measuring interval}
      meas1 := min(meas1, meas2 - mindm);
      end;
    end;
  csvana_datt_upd;                     {sanitize the altered state}

leave:                                 {common exit point}
  csvana_draw_leave;                   {leave drawing mode}
  end;
