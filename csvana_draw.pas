{   Drawing routines.  The drawing state is kept internal to this module.
}
module csvana_draw;
define csvana_draw;
%include 'csvana.ins.pas';
%include 'vect.ins.pas';
%include 'img.ins.pas';
%include 'rend.ins.pas';

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
  {
  *   Application configuration state.  This can change with the drawing area
  *   size.
  }
  namesx: real;                        {X of data value names right ends}
  datlx, datrx: real;                  {left and right X of data bars}
  datvalh: real;                       {height of each data value bar}
  induby: real;                        {bottom Y of independent variable units}
  indlty: real;                        {top Y of independent variable labels}
  indtlby: real;                       {bottom Y of ind value labeled tick marks}
  indtuby: real;                       {bottom Y of ind value unlabled tick marks}
  datv1y: real;                        {center Y of first data value bar}
  datvdy: real;                        {DY for each successive data value bar}
  {
  *   Current application control state.
  }
  csv_p: csvana_root_p_t;              {points to root of CSV file data}
  datt1, datt2: double;                {data time range to display}
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
  datrx := devw - (2.0 * pixw);        {right X of data value bars}

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

  rend_set.exit_rend^;
  end;
{
********************************************************************************
*
*   Local subroutine DRAW_DEPVAR (N)
*
*   Draw the data for the Nth dependent variable.  N is in the range of 1 to
*   CSV.NVALS.
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
  p.x :=
    datlx +                            {offset for 0 into range}
    ((rec_p^.time - datt1)/(datt2 - datt1)) * {fraction into range}
    (datrx - datlx);                   {size of display range}
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
(*
  if n > 2 then return;                {***** TEMP DEBUG for speedup *****}
*)



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

begin
  rend_set.enter_rend^;

  rend_set.rgb^ (0.0, 0.0, 0.0);
  rend_prim.clear_cwind^;
{
*   Draw the names of each dependent variable.
}
  rend_set.rgb^ (0.7, 0.7, 0.7);
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
*   Draw the data bar backgrounds.
}
  rend_set.rgb^ (0.25, 0.25, 0.25);
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
*   Subroutine CSVANA_DRAW (CSV, T1, T2)
*
*   Show the CSV data, initially from relative time T1 to T2.  User interactions
*   may subsequently change what is shown.
}
procedure csvana_draw (                {draw section of CSV data}
  in      csv: csvana_root_t;          {CSV data to draw}
  in      t1, t2: double);             {initial time interval to show}
  val_param;

var
  ev: rend_event_t;                    {last RENDlib event received}
  stat: sys_err_t;                     {completion status}

label
  resize, redraw, next_event;

begin
  csv_p := addr(csv);                  {save control parameters}
  datt1 := t1;
  datt2 := t2;

  rend_start;                          {start up RENDlib}
  rend_open (                          {create the RENDlib drawing device}
    string_v('screen'(0)),             {device name}
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
  rend_set.exit_rend^;

resize:                                {reconfigure to current drawing area size}
  csvana_resize;

redraw:
  csvana_redraw;                       {redraw whole display with current parameters}

next_event:                            {back here to get the next event}
  rend_set.enter_level^ (0);           {make sure to be out of graphics mode}
  rend_event_get (ev);                 {wait for the next event}
  case ev.ev_type of                   {what kind of event is it ?}

rend_ev_close_k,                       {drawing device got closed, RENDlib still open}
rend_ev_close_user_k: begin            {user wants to close the drawing device}
      rend_end;
      return;
      end;

rend_ev_resize_k,                      {drawing area size changed}
rend_ev_wiped_resize_k: begin          {pixels wiped out due to size change}
      goto resize;
      end;

rend_ev_wiped_rect_k: begin            {rectangle of pixels got wiped out}
      goto redraw;
      end;

    end;                               {end of event type cases}
  goto next_event;                     {done processing this event, back for next}
  end;
