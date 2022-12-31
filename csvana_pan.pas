{   Interactive graphical panning.
}
module csvana_pan;
define csvana_pan;
%include 'csvana.ins.pas';

var
  xst, xen: real;                      {starting and ending X being dragged}
  ydrag: real;                         {Y to show drag line at}
  xdrag: real;                         {X end of drag line, if shown}
  dragshown: boolean;                  {drag line is currently shown}
{
********************************************************************************
*
*   Local subroutine DRAG_DRAW
*
*   Draw the drag line to XDRAG.  This line is assumed to be drawn in XOR mode,
*   which toggles visibility each draw.  DRAGSHOW is updated accordingly.
}
procedure drag_draw;
  val_param; internal;

begin
  rend_set.cpnt_2d^ (xst, ydrag);      {draw the line, assume XOR mode}
  rend_prim.vect_2d^ (xdrag, ydrag);

  dragshown := not dragshown;          {update visibility indicator}
  end;
{
********************************************************************************
*
*   Local function CLIPX (X)
*
*   Return the 2D X coordinate clipped to the valid drag end range.
}
function clipx (                       {clip to valid drag end range}
  in      x: real)                     {input 2D X}
  :real;                               {clipped result}
  val_param; internal;

begin
  clipx := max(datlx, min(datrx, x));
  end;
{
********************************************************************************
*
*   Local subroutine DRAGTO (X)
*
*   Update the drag end coordinate to X, and make sure the drag line is visible.
}
procedure dragto (                     {update drag end location}
  in      x: real);                    {updated 2D X drag end coordinate}
  val_param; internal;

begin
  if dragshown then begin              {drag line to old coordinate is visible ?}
    drag_draw;                         {erase it}
    end;

  xen := clipx(x);                     {update new drag end X}
  xdrag := xen;                        {update end of new drag line}
  drag_draw;                           {draw the new drag line}
  end;
{
********************************************************************************
*
*   Subroutine CSVANA_PAN (KEY, REDRAW)
*
*   Drag a displayed X position to pan the display.
*
*   KEY is the key event that started the pan operation.  This is guaranteed to
*   be a key down event.  If the display should be redrawn as a result of the
*   pan operation, then REDRAW is set to TRUE.  Otherwise, REDRAW is unaltered.
}
procedure csvana_pan (                 {pan the display along the X axis}
  in      key: rend_event_key_t;       {key press event to start drag}
  in out  redraw: boolean);            {will set to TRUE if redraw required}
  val_param;

var
  x, y: real;                          {scratch X,Y coordinate}
  p1, p2: vect_2d_t;                   {points for transformations}
  dd: double;                          {drag size in X data space}
  d1, d2: double;                      {updated data range to display}
  ev: rend_event_t;                    {last event read from queue}

label
  event, evnotus, dragged, leave;

begin
  csvana_draw_enter;                   {enter drawing mode}
  pix2d (key.x, key.y, x, ydrag);      {get drag start coordinate in 2D space}
  xst := clipx(x);                     {init drag start X}
  xen := xst;                          {init to no net drag displacement}

  rend_set.iterp_pixfun^ (rend_iterp_red_k, rend_pixfun_xor_k); {set XOR mode}
  rend_set.iterp_pixfun^ (rend_iterp_grn_k, rend_pixfun_xor_k);
  rend_set.iterp_pixfun^ (rend_iterp_blu_k, rend_pixfun_xor_k);
  rend_set.rgb^ (0.5, 0.5, 0.5);       {color for maximum XOR contrast}
  dragshown := false;                  {init to drag line not currently shown}

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
        x, y);                         {returned 2D coordinates of drag end}
      xen := clipx(x);                 {set drag end X}
      goto dragged;                    {go handle drag results}
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
      dragto (x);                      {update drag state to the new coordinate}
      end;

otherwise                              {unrecognized or unexpected event}
    goto evnotus;                      {this event is not for us}
    end;                               {end of event type cases}
  goto event;                          {back to get the next event}

evnotus:                               {event isn't for us, push back and end drag}
  rend_event_push (ev);                {put event back onto event queue}
{
*   The drag operation has completed.  The drag was from XST to XEN.  The last
*   drag line may still be shown.
}
dragged:
  if dragshown then begin              {drag line is currently shown ?}
    drag_draw;                         {erase it}
    end;

  rend_set.iterp_pixfun^ (rend_iterp_red_k, rend_pixfun_insert_k); {restore pixfun}
  rend_set.iterp_pixfun^ (rend_iterp_grn_k, rend_pixfun_insert_k);
  rend_set.iterp_pixfun^ (rend_iterp_blu_k, rend_pixfun_insert_k);
  {
  *   Make the updated data range to display in D1 and D2.  The actual displayed
  *   data range DATT1,DATT2 is not altered.
  }
  dd := datdt * (xen - xst) / datdx;   {amount of drag in X data space}
  d1 := datt1 - dd;                    {update data interval start}
  d1 := max(d1, csv_p^.rec_p^.time);   {clip to data start}
  d2 := d1 + datdt;                    {preserve size of data interval}
  d2 := min(d2, csv_p^.rec_last_p^.time); {clip to data end}
  d1 := d2 - datdt;                    {update data start after clip}
  {
  *   Abort if not moved at least one whole pixel.
  }
  p1.x := dattx (datt1);               {starting point in 2D space}
  p1.y := ydrag;
  rend_get.xfpnt_2d^ (p1, p2);         {find the point in pixel space}
  x := p2.x;                           {save resulting pixel X coordinate}

  p1.x := dattx (d1);                  {ending point in 2D space}
  rend_get.xfpnt_2d^ (p1, p2);         {find the point in pixel space}
  if abs(p2.x - x) < 1.0 then goto leave; {less than 1 pixel displacement ?}
  {
  *   Update the drawing configuration to the new data range.
  }
  datt1 := d1;                         {set new data range to display}
  datt2 := d2;

  csvana_datt_upd;                     {update data range control state}
  redraw := true;                      {display will need to be redrawn}

leave:                                 {common exit point}
  csvana_draw_leave;                   {leave drawing mode}
  end;
