{   Drawing routines.  The drawing state is kept internal to this module.
}
module csvana_draw;
define csvana_draw_run;
%include 'csvana.ins.pas';
%include 'vect.ins.pas';
%include 'img.ins.pas';
%include 'rend.ins.pas';
%include 'gui.ins.pas';

const
  text_minfrx = 1.0 / 90.0;            {min text size, fraction of X dimension}
  text_minfry = 1.0 / 65.0;            {min text size, fraction of Y dimension}
  text_minpix = 13;                    {min text size, pixels}

var
  {
  *   RENDlib configuration state.
  }
  rendev: rend_dev_id_t;               {RENDlib ID for our drawing device}
  bitmap: rend_bitmap_handle_t;        {handle to our pixels bitmap}
  bitmap_alloc: boolean;               {bitmap memory is allocated}
  tparm: rend_text_parms_t;            {text drawing control parameters}
  vparm: rend_vect_parms_t;            {vector drawing control parameters}
  pparm: rend_poly_parms_t;            {polygon drawing control parameters}
  cliph: rend_clip_2dim_handle_t;      {clip rectangle handle}
  devdx, devdy: sys_int_machine_t;     {drawing device size, pixels}
  devasp: real;                        {drawing device aspect ratio}
  devw, devh: real;                    {drawing device size, 2D space}
  pixw, pixh: real;                    {width and height of 1 pixel in 2D space}
  szmem_p: util_mem_context_p_t;       {mem context for this config, cleared on resize}
  {
  *   Application configuration state.  This can change with the drawing area
  *   size.
  }
  namesx: real;                        {X of data value names right ends}
  datlx, datrx: real;                  {left and right X of data bars}
  datdx: real;                         {data bars X range}
  datvalh: real;                       {height of each data value bar}
  induby: real;                        {bottom Y of independent variable units}
  indlty: real;                        {top Y of independent variable labels}
  indtlby: real;                       {bottom Y of ind value labeled tick marks}
  indtuby: real;                       {bottom Y of ind value unlabled tick marks}
  datv1y: real;                        {center Y of first data value bar}
  datvdy: real;                        {DY for each successive data value bar}
  xticks_p: gui_tick_p_t;              {tick marks for X axis labels}
  {
  *   Current application control state.
  }
  csv_p: csvana_root_p_t;              {points to root of CSV file data}
  datt1, datt2: double;                {data time range to display}
  datdt: double;                       {data time interval size}
  meas1, meas2: real;                  {start/end measuring interval data values}
  devname: string_var80_t;             {RENDlib drawing device name}
{
********************************************************************************
*
*   Local function TIMEX (T)
*
*   Returns the X coordinate for the data time T.
}
function timex (                       {get display X for a data time}
  in      t: double)                   {data time to get X coordinate for}
  :real;                               {X in RENDlib 2D space}
  val_param; internal;

begin
  timex := ((t - datt1) * datdx / datdt) + datlx;
  end;
{
********************************************************************************
*
*   Local function TEXT_WIDTH (S)
*
*   Return the baseline length the text string S would be drawn with.  The
*   resulting length is valid in the 2D coordinate space.
}
function text_width (                  {get text string draw width}
  in      s: univ string_var_arg_t)    {the string to get drawing width of}
  :real;                               {baseline length in 2D coordinate space}
  val_param; internal;

var
  bv: vect_2d_t;                       {baseline vector}
  up: vect_2d_t;                       {height vector}
  ll: vect_2d_t;                       {lower left corner coordinate}

begin
  rend_get.txbox_txdraw^ (             {get box text would be drawn in}
    s.str, s.len,                      {text string and string length}
    bv, up, ll);                       {returned drawing box parameters}

  text_width := sqrt(sqr(bv.x) + sqr(bv.y)); {text basline length}
  end;
{
********************************************************************************
*
*   Local subroutine MEAS_CLIP
*
*   Clip the measurement interval to the currently displayed range.  The
*   interval from MEAS1 to MEAS2 will also be guaranteed to be in ascending
*   order, and a minimum fraction of the displayed range.
}
procedure meas_clip;                   {clip measurement interval to displayed range}
  val_param; internal;

const
  minmeas = 0.01;                      {min meas interval as fraction of disp range}

var
  d: double;                           {min meas interval size}

begin
  d := datdt * minmeas;                {make min meas interval size}

  meas1 := max(meas1, datt1);          {clip measurement interval to data range}
  meas2 := max(meas2, meas1 + d);
  meas2 := min(meas2, datt2);
  meas1 := min(meas1, meas2 - d);
  end;
{
********************************************************************************
*
*   Local subroutine CSVANA_RESIZE
*
*   Configure or re-configure to the current drawing device size.
}
procedure csvana_resize;
  val_param; internal;

var
  xb, yb, ofs: vect_2d_t;              {2D transform}
  ii: sys_int_machine_t;               {scratch integer}
  r: real;                             {scratch floating point}
  name_p: csvana_name_p_t;             {to dependent value name descriptor}

begin
  if szmem_p <> nil then begin         {mem context exists for previous size ?}
    util_mem_context_del (szmem_p);    {delete all dyn mem for old size config}
    end;
  util_mem_context_get (               {make mem context for the size config}
    util_top_mem_context, szmem_p);

  rend_set.enter_rend^;
{
*   Reconfigure RENDlib for drawing into the new current draw area.
}
  rend_set.dev_reconfig^;              {look at device parameters and reconfigure}
  rend_get.image_size^ (devdx, devdy, devasp); {get draw area size, aspect ratio}

  if bitmap_alloc then begin           {a bitmap is currently allocated ?}
    rend_set.dealloc_bitmap^ (bitmap); {deallocate the old bitmap memory}
    end;
  rend_set.alloc_bitmap^ (             {allocate new bitmap memory}
    bitmap,                            {bitmap to allocate memory for}
    devdx, devdy,                      {numbers of pixels in X and Y}
    3,                                 {bytes per pixel}
    rend_scope_dev_k);                 {scope of the bitmap}
  bitmap_alloc := true;                {bitmap now has memory allocated}

  rend_set.clip_2dim^ (                {set 2D pixel space clipping}
    cliph,                             {handle to clip window}
    0, devdx,                          {X drawing limits}
    0, devdy,                          {Y drawing limits}
    true);                             {draw inside, clip outside}
  {
  *   Set up the 2d transform for 0,0 in the lower left corner, square
  *   coordinates, and 100 size for the smallest dimension.  The 2D transform
  *   converts into a space where 0,0 is in the middle, with the +-1 square
  *   maximized to the minimum dimension.
  }
  xb.x := 2.0 / 100.0;
  xb.y := 0.0;
  yb.x := 0.0;
  yb.y := 2.0 / 100.0;
  if devasp >= 1.0
    then begin                         {draw area is wider than tall}
      ofs.x := -devasp;
      ofs.y := -1.0;
      devw := 100.0 * devasp;
      devh := 100.0;
      end
    else begin                         {draw area is taller than wide}
      ofs.x := -1.0;
      ofs.y := -1.0 / devasp;
      devw := 100.0;
      devh := 100.0 / devasp;
      end
    ;
  rend_set.xform_2d^ (xb, yb, ofs);    {set the 2D transform}

  pixw := devw / devdx;                {width of one pixel in 2D space}
  pixh := devh / devdy;                {height of one pixel in 2D space}
  {
  *   Set the text size.  The text size is derived from the draw area size and
  *   the constants TEXT_MINFRX, TEXT_MINRFY, and TEXT_MINPIX at the top of this
  *   module.  The text height is adjusted to be a whole odd number of pixels.
  }
  r := max(                            {make min required text size in pixels}
    text_minpix,                       {abs min, pixels}
    devdx * text_minfrx,               {min as fraction of X dimension}
    devdy * text_minfry);              {min as fraction of Y dimension}
  ii := trunc(r + 0.999);              {round up to full integer}
  if not odd(ii) then begin            {even number of pixels ?}
    ii := ii + 1;                      {make odd, one row will be in center}
    end;
  tparm.size := devh * ii / devdy;     {size in 2D space to get desired pixel height}
  rend_set.text_parms^ (tparm);        {set the text parameters in RENDlib}
{
*   Update the application configuration to the new drawing area dimensions.
}
  {
  *   Find the length of the longest data value name.  This will be used to
  *   decide NAMESX, which is the right end X of where to write the data value
  *   names.
  }
  r := 0.0;                            {init max data value name length}
  name_p := csv_p^.name_p;             {init to first data value name}
  while name_p <> nil do begin         {scan the list of data value names}
    r := max(r, text_width(name_p^.name)); {update max width to this name}
    name_p := name_p^.next_p;          {to next name in list}
    end;                               {back to check this new name}

  namesx := r + pixw;                  {X to anchor right end of data value names}
  {
  *   Find the various locations and sizes of drawing elements.
  }
  datvalh := tparm.size * 1.2;         {0 to 1 height of each data value bar}
  datlx := namesx + max(2.0 * pixw, tparm.size * 0.1); {left X of data value bars}
  datrx :=                             {leave room at right for some label chars}
    devw - (3.5 * tparm.size * tparm.width);
  datdx := datrx - datlx;
  meas_clip;                           {clip measurement range displayed range}

  induby := tparm.size * 0.5;          {bottom of independent variable units text}
  indlty := induby + (tparm.size * 2.5); {top of ind variable axis labels}
  indtlby := indlty + (tparm.size * 0.2); {bottom Y of labeled ind val tick lines}
  indtuby := indtlby + (datvalh * 0.2); {bottom Y of unlabled ind val tick lines}
  datv1y := indtuby + (datvalh * 0.75); {center Y of first data value bar}

  datvdy := datvalh * 1.5;             {init Y stride per data value}
  if csv_p^.nvals >= 2 then begin      {Y stride will be used ?}
    r := devh - (datvalh * 1.0);       {max Y of top data bar for full fit}
    datvdy := max(                     {make final Y stride per data bar}
      datvdy,                          {min allowed value}
      (r - datv1y) / (csv_p^.nvals - 1) {spread out over available height}
      );
    end;

  gui_ticks_make (                     {compute X axis labels and tick marks}
    datt1, datt2,                      {values range}
    datrx - datlx,                     {coordinate range to display over}
    true,                              {labels will be stacked horizontally}
    szmem_p^,                          {parent memory context for tick mark descriptors}
    xticks_p);                         {returned pointer to first tick mark}

  rend_set.exit_rend^;
  end;
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
  p.x := timex (rec_p^.time);          {X for this data time}
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
  x := timex(t);                       {X to draw indicator at}
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
*   Local subroutine CSVANA_REDRAW
*
*   Redraw the whole display with the current parameters.
}
procedure csvana_redraw;
  val_param; internal;

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
    x := timex (tick_p^.val);          {make X for this data time}
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
      rend_set.cpnt_2d^ (timex(tick_p^.val), indlty);
      rend_prim.text^ (tick_p^.lab.str, tick_p^.lab.len);
      end;
    tick_p := tick_p^.next_p;          {to next tick descriptor}
    end;                               {back to do next tick}
{
*   Draw the measurement interval start and end lines.
}
  rend_set.rgb^ (0.2, 1.0, 0.2);       {interval start indicator}
  draw_meas (meas1);

  rend_set.rgb^ (1.0, 0.2, 0.2);       {interval end indicator}
  draw_meas (meas2);
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
*   Draw the signals.
}
  rend_set.rgb^ (1.0, 1.0, 1.0);
  for ii := 1 to csv_p^.nvals do begin {loop over the dependent variables}
    draw_depvar (ii);                  {plot the data for this variable}
    end;                               {back for next dependent variable}

  rend_set.exit_rend^;
  end;
{
********************************************************************************
*
*   Local subroutine CSVANA_DRAW
*
*   This routine is run in a separate thread.  It draws the data, then services
*   graphics events until the drawing device is closed or the user requests it
*   to be closed.
}
procedure csvana_draw (                {thread to do drawing in background}
  in      arg: sys_int_adr_t);         {arbitrary argument, unused}
  val_param;

var
  ev: rend_event_t;                    {last RENDlib event received}
  evwait: boolean;                     {wait on next event}
  do_resize: boolean;                  {update to resize pending}
  do_redraw: boolean;                  {redraw pending}
  stat: sys_err_t;                     {completion status}

label
  resize, redraw, next_event;

begin
  rend_start;                          {start up RENDlib}

  if devname.len <= 0 then begin       {drawing device name not specified ?}
    string_vstring (devname, 'right'(0), -1); {use default}
    end;
  rend_open (                          {create the RENDlib drawing device}
    devname,                           {device name}
    rendev,                            {returned RENDlib device ID}
    stat);
  sys_error_abort (stat, '', '', nil, 0);

  rend_set.enter_rend^;

  rend_set.alloc_bitmap_handle^ (rend_scope_dev_k, bitmap);
  bitmap_alloc := false;

  rend_set.iterp_on^ (rend_iterp_red_k, true);
  rend_set.iterp_on^ (rend_iterp_grn_k, true);
  rend_set.iterp_on^ (rend_iterp_blu_k, true);

  rend_set.iterp_bitmap^ (rend_iterp_red_k, bitmap, 0);
  rend_set.iterp_bitmap^ (rend_iterp_grn_k, bitmap, 1);
  rend_set.iterp_bitmap^ (rend_iterp_blu_k, bitmap, 2);

  rend_set.event_req_close^ (true);
  rend_set.event_req_resize^ (true);
  rend_set.event_req_wiped_resize^ (true);
  rend_set.event_req_wiped_rect^ (true);

  rend_get.text_parms^ (tparm);
  tparm.width := 0.72;
  tparm.height := 1.0;
  tparm.slant := 0.0;
  tparm.rot := 0.0;
  tparm.lspace := 0.7;
  tparm.coor_level := rend_space_2d_k;
  tparm.poly := false;

  rend_get.vect_parms^ (vparm);
  vparm.poly_level := rend_space_none_k;
  vparm.subpixel := true;
  rend_set.vect_parms^ (vparm);

  rend_get.poly_parms^ (pparm);
  pparm.subpixel := true;
  rend_set.poly_parms^ (pparm);

  rend_get.clip_2dim_handle^ (cliph);  {create 2DIM clip window, get handle}

  rend_set.update_mode^ (rend_updmode_buffall_k);
  szmem_p := nil;                      {init to no mem context for current size}
  rend_set.exit_rend^;

resize:                                {reconfigure to current drawing area size}
  do_resize := false;                  {clear pending update to new size}
  csvana_resize;

redraw:
  do_redraw := false;                  {clear pending redraw required}
  csvana_redraw;                       {redraw whole display with current parameters}

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
{
********************************************************************************
*
*   Subroutine CSVANA_DRAW_RUN (CSV, RENDEV, T1, T2)
*
*   Start the background thread to draw the CSV data.
*
*   RENDEV is the RENDlib device name to use for the drawing.  When RENDEV is
*   the empty string, then a default is automatically chosen.
*
*   T1 and T2 are the initial data time interval to show.
*
*   This routine only launches the background drawing task and returns quickly.
}
procedure csvana_draw_run (            {start drawing, runs in separate thread}
  in      csv: csvana_root_t;          {CSV data to draw}
  in      rendev: univ string_var_arg_t; {name of draw dev to use, blank = default}
  in      t1, t2: double);             {initial time interval to show}
  val_param;

var
  thid: sys_sys_thread_id_t;           {ID of drawing thread}
  stat: sys_err_t;                     {completion status}

begin
  csv_p := addr(csv);                  {save control parameters}
  datt1 := t1;
  datt2 := t2;
  datdt := datt2 - datt1;
  devname.max := size_char(devname.str);
  string_copy (rendev, devname);

  meas1 := datt1;                      {init measurement interval to full data range}
  meas2 := datt2;

  sys_thread_create (                  {start the drawing thread}
    addr(csvana_draw),                 {pointer to root thread routine}
    0,                                 {argument passed to thread, not used}
    thid,                              {returned thread ID}
    stat);
  sys_error_abort (stat, '', '', nil, 0);
  end;
