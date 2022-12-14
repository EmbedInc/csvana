{   Update to drawing area size.
}
module csvana_draw_resize;
define csvana_draw_resize;
%include 'csvana.ins.pas';

const
  text_minfrx = 1.0 / 90.0;            {min text size, fraction of X dimension}
  text_minfry = 1.0 / 65.0;            {min text size, fraction of Y dimension}
  text_minpix = 13;                    {min text size, pixels}

var
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

  text_width := sqrt(sqr(bv.x) + sqr(bv.y)); {text baseline length}
  end;
{
********************************************************************************
*
*   Local subroutine CSVANA_DRAW_RESIZE
*
*   Configure or re-configure to the current drawing device size.
}
procedure csvana_draw_resize;
  val_param;

var
  xb, yb, ofs: vect_2d_t;              {2D transform}
  ii: sys_int_machine_t;               {scratch integer}
  r: real;                             {scratch floating point}
  name_p: csvana_name_p_t;             {to dependent value name descriptor}

begin
  csvana_draw_enter;                   {start single-threaded drawing}

  if szmem_p <> nil then begin         {mem context exists for previous size ?}
    util_mem_context_del (szmem_p);    {delete all dyn mem for old size config}
    end;
  util_mem_context_get (               {make mem context for the size config}
    util_top_mem_context, szmem_p);
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

  csvana_draw_leave;                   {end single-threaded drawing}
  end;
