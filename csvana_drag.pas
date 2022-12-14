{   Interactive graphical object dragging.
}
module csvana_drag;
define csvana_drag_cursor;
%include 'csvana.ins.pas';
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
  ev: rend_event_t;                    {last event read from queue}

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
    end;                               {end of event type cases}

evnotus:                               {event isn't for us, push back and end drag}
  rend_event_push (ev);                {put event back onto event queue}

done:                                  {end the drag}
  csvana_datt_upd;                     {sanitize the altered state}

leave:                                 {common exit point}
  csvana_draw_leave;                   {leave drawing mode}
  end;
