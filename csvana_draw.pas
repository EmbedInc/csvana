{   Drawing routines.
}
module csvana_draw;
define csvana_draw;
%include 'csvana.ins.pas';
{
********************************************************************************
*
*   Local subroutine DRAW_DEPVAR (N)
*
*   Draw the data for the Nth dependent variable.  N must be in the range of 1
*   to CSV.NVALS.
}
procedure draw_depvar (                {draw data for dependent variable}
  in      n: sys_int_machine_t);       {1-N number of the dependent variable}
  val_param; internal;

type
  inout_k_t = (                        {where is point relative to displayable range}
    inout_bef_k,                       {before}
    inout_in_k,                        {in}
    inout_aft_k);                      {after}

  point_t = record                     {data about one point}
    x: real;                           {display X coor, clipped to display range}
    y: real;                           {display Y coor}
    inout: inout_k_t;                  {where point is relative to display range}
    end;

var
  ybot: real;                          {data bar bottom Y, height is DATVALH}
  rec_p: csvana_rec_p_t;               {to current data record at one time value}
  pprev, pcurr: point_t;               {previous and current data points}

label
  next_rec;
{
****************************************
*
*   Internal subroutine GET_POINT (P)
*   This routine is internal to DRAW_DEPVAR.
*
*   Get the info about the data value N within the current record (pointed to by
*   REC_P).
}
procedure get_point (                  {get info about current point}
  out     p: point_t);                 {returned displayable point descriptor}
  val_param; internal;

label
  have_inout;

begin
  if rec_p^.time < datt1 then begin    {before displayable range ?}
    p.inout := inout_bef_k;
    p.x := datlx;
    goto have_inout;
    end;
  if rec_p^.time > datt2 then begin    {after displayable range ?}
    p.inout := inout_aft_k;
    p.x := datrx;
    goto have_inout;
    end;
  p.inout := inout_in_k;               {within displayable range}
  p.x := dattx (rec_p^.time);          {X for this data time}
have_inout:                            {INOUT and X all set}

  if (n < 1) or (n > csv_p^.nrec) then begin {invalid variable number}
    p.y := ybot;                       {return arbitrary value}
    return;
    end;

  p.y := ybot +                        {offset for data value 0}
    max(-0.5, min(1.5, rec_p^.data[n])) * {clipped data value}
    datvalh;                           {size of Y range for 0-1 value}
  end;
{
****************************************
*
*   Start of executable code for subroutine DRAW_DEPVAR.
}
begin
  ybot :=                              {data bar bottom Y}
    datv1y + (datvdy * (n - 1)) - (datvalh / 2.0);

  rec_p := csv_p^.rec_p;               {init to first record}
  if rec_p = nil then return;          {no data to plot ?}
  get_point (pprev);                   {init previous point info}
  if pprev.inout = inout_aft_k then begin {after displayable range ?}
    return;                            {all point after range, nothing to draw}
    end;
  if pprev.inout = inout_in_k then begin {this point is displayable ?}
    rend_set.cpnt_2d^ (pprev.x, pprev.y);
    end;

  rec_p := rec_p^.next_p;              {to second record}
  while rec_p <> nil do begin          {loop over the successive data values}
    get_point (pcurr);                 {get current point info}

    if pcurr.inout = inout_bef_k then begin {still before display range ?}
      pprev := pcurr;                  {update previous point for next time}
      goto next_rec;
      end;
    if pcurr.inout = inout_aft_k then begin {just crossed out of range ?}
      rend_set.cpnt_2d^ (pprev.x, pprev.y); {go to previous point}
      rend_prim.vect_2d^ (pcurr.x, pprev.y); {draw to end with previous value}
      return;                          {past range, all done}
      end;
    {
    *   The new point is within the displayable range.
    }
    if pcurr.y <> pprev.y then begin   {value changed ?}
      if pprev.inout = inout_bef_k then begin {was previously before range ?}
        rend_set.cpnt_2d^ (pprev.x, pprev.y); {go to previous point}
        end;
      rend_prim.vect_2d^ (pcurr.x, pprev.y); {old value up to this point}
      rend_prim.vect_2d^ (pcurr.x, pcurr.y); {new value vertically only}
      pprev := pcurr;                  {update previous point for next time}
      end;

next_rec:                              {done with this record, on to next}
    rec_p := rec_p^.next_p;            {to next record}
    end;                               {back to process this new record}

  if pcurr.x <> pcurr.y then begin     {last segment not yet drawn ?}
    if pprev.inout = inout_bef_k then begin {was previously before range ?}
      rend_set.cpnt_2d^ (pprev.x, pprev.y); {go to previous point}
      end;
    rend_prim.vect_2d^ (pcurr.x, pprev.y); {old value up to this point}
    end;
  end;
{
********************************************************************************
*
*   Local subroutine DRAW_MEAS (T)
*
*   Draw a measurement indicator at the data value T.
}
procedure draw_meas (                  {draw measurement indictor}
  in      t: double);                  {time value to draw indicator at}
  val_param; internal;

const
  polyn = 3;                           {max points in 2D polygon}

var
  x: real;                             {X coordinate to draw indicator at}
  y: real;                             {bottom Y of vertical indicator line}
  mxofs: real;                         {left/right offset of marker triangle}
  mdy: real;                           {height of marker triangle}
  poly: array[1..polyn] of vect_2d_t;  {2D polygon verticies}

begin
  x := dattx(t);                       {X to draw indicator at}
  y := datv1y - (datvalh * 0.5);       {Y of bottom of vertical indicator line}
  mdy := tparm.size * 0.5;             {height of marker triangle}
  mxofs := mdy * 0.5;                  {half-width of marker triangle}

  rend_set.cpnt_2d^ (x, devh);         {draw the vertical indicator line}
  rend_prim.vect_2d^ (x, y);

  poly[1].x := x;                      {draw marker}
  poly[1].y := y;
  poly[2].x := x - mxofs;
  poly[2].y := y - mdy;
  poly[3].x := x + mxofs;
  poly[3].y := y - mdy;
  rend_prim.poly_2d^ (3, poly);
  end;
{
********************************************************************************
*
*   Subroutine CSVANA_REDRAW
*
*   Redraw the whole display with the current parameters.
}
procedure csvana_draw;
  val_param;

var
  name_p: csvana_name_p_t;             {to dependent variable name}
  ii: sys_int_machine_t;               {scratch integer}
  x, y: real;                          {scratch coordinate}
  tick_p: gui_tick_p_t;                {to current tick mark descriptor}

begin
  rend_set.enter_rend^;

  rend_set.rgb^ (0.0, 0.0, 0.0);
  rend_prim.clear_cwind^;
{
*   Draw the names of each dependent variable.
}
  rend_set.rgb^ (0.70, 0.70, 0.70);
  tparm.start_org := rend_torg_mr_k;   {anchor text at right center}
  rend_set.text_parms^ (tparm);

  ii := 0;                             {init 0-N offset from first name}
  name_p := csv_p^.name_p;             {init to first name in list}
  while name_p <> nil do begin         {loop over the list of names}
    y := datv1y + (datvdy * ii);       {make Y for this data value}
    rend_set.cpnt_2d^ (namesx, y);     {place middle right of name}
    rend_prim.text^ (name_p^.name.str, name_p^.name.len); {draw the name}
    name_p := name_p^.next_p;          {to next name in list}
    ii := ii + 1;                      {make Y offset of this new name}
    end;                               {back to draw the new name}
{
*   Draw X axis units name.
}
  rend_set.rgb^ (0.7, 0.7, 0.7);
  tparm.start_org := rend_torg_lm_k;   {anchor text at bottom center}
  rend_set.text_parms^ (tparm);

  x := (datlx + datrx) / 2.0;
  rend_set.cpnt_2d^ (x, induby);
  rend_prim.text^ ('Seconds', 7);
{
*   Draw the X tick marks and X axis labels.  All the tick marks are in minor to
*   major order starting at XTICKS_P.  The list of ticks is traversed twice.
*   the vertical tick lines are drawn the first pass, with labels written on the
*   second pass.  This is because the labels and tick line have different
*   colors.
}
  {
  *   Draw the vertical lines for each tick.
  }
  ii := -1;                            {init current tick level to invalid}
  tick_p := xticks_p;                  {init to first tick in list}
  while tick_p <> nil do begin         {scan the list of tick marks}
    if tick_p^.level <> ii then begin  {starting a new level ?}
      ii := tick_p^.level;             {remember level now at}
      case ii of                       {special handling per level}
0:      begin                          {major tick}
          rend_set.rgb^ (0.25, 0.25, 0.25);
          y := indtlby;
          end;
1:      begin                          {one level subordinate}
          rend_set.rgb^ (0.20, 0.20, 0.20);
          y := indtuby;
          end;
otherwise                              {all other more subordinate ticks}
        rend_set.rgb^ (0.15, 0.15, 0.15);
        y := indtuby;
        end;
      end;                             {end of switching to new tick level}
    x := dattx (tick_p^.val);          {make X for this data time}
    rend_set.cpnt_2d^ (x, y);          {draw vertical line for this tick}
    rend_prim.vect_2d^ (x, devh);
    tick_p := tick_p^.next_p;          {to next tick descriptor}
    end;                               {back to do next tick}
  {
  *   Draw the labels for each tick with a label string.
  }
  rend_set.rgb^ (0.70, 0.70, 0.70);
  tparm.start_org := rend_torg_um_k;   {anchor text at upper middle}
  rend_set.text_parms^ (tparm);

  tick_p := xticks_p;                  {init to first tick in list}
  while tick_p <> nil do begin         {scan the list of tick marks}
    if tick_p^.lab.len > 0 then begin  {this tick has a label string ?}
      rend_set.cpnt_2d^ (dattx(tick_p^.val), indlty);
      rend_prim.text^ (tick_p^.lab.str, tick_p^.lab.len);
      end;
    tick_p := tick_p^.next_p;          {to next tick descriptor}
    end;                               {back to do next tick}
{
*   Draw the data bar backgrounds.
}
  rend_set.rgb^ (0.30, 0.30, 0.30);
  for ii := 0 to csv_p^.nvals-1 do begin {up the data bars}
    y := datv1y + (datvdy * ii);       {make center Y for this data value}
    y := y - (datvalh / 2.0);          {bottom Y of this data bar}
    rend_set.cpnt_2d^ (datlx, y);      {to bottom left corner}
    rend_prim.rect_2d^ (               {draw data bar background rectangle}
      datrx - datlx,                   {X displacement}
      datvalh);                        {Y displacement}
    end;                               {back for next dependent data value}
{
*   Draw the measurement interval start and end lines and the data cursor.
}
  rend_set.rgb^ (0.0, 0.9, 0.0);       {interval start indicator}
  draw_meas (meas1);

  rend_set.rgb^ (1.0, 0.2, 0.2);       {interval end indicator}
  draw_meas (meas2);

  rend_set.rgb^ (0.2, 0.2, 1.0);       {data cursor}
  draw_meas (curs);
{
*   Draw the signals.
}
  rend_set.rgb^ (1.0, 1.0, 1.0);
  for ii := 1 to csv_p^.nvals do begin {loop over the dependent variables}
    draw_depvar (ii);                  {plot the data for this variable}
    end;                               {back for next dependent variable}

  rend_set.exit_rend^;
  end;
