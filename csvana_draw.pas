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
{
********************************************************************************
*
*   Local subroutine CSVANA_REDRAW
*
*   Redraw the whole display with the current parameters.
}
procedure csvana_redraw;
  val_param; internal;

begin
  rend_set.enter_rend^;

  rend_set.rgb^ (0.0, 0.0, 0.0);
  rend_prim.clear_cwind^;

  rend_set.rgb^ (0.7, 0.7, 0.7);
  rend_set.cpnt_2d^ (devw, devh/2);
  rend_prim.vect_2d^ (devw/2, devh);
  rend_prim.vect_2d^ (0.0, devh/2);
  rend_prim.vect_2d^ (devw/2, 0.0);
  rend_prim.vect_2d^ (devw, devh/2);

  rend_set.rgb^ (1.0, 1.0, 1.0);
  rend_set.cpnt_2d^ (devw/2, devh/2);
  tparm.start_org := rend_torg_mid_k;
  rend_set.text_parms^ (tparm);
  rend_prim.text^ ('Hello, world!', 13);

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
  xb, yb, ofs: vect_2d_t;              {2D transform}
  ev: rend_event_t;                    {last RENDlib event received}
  ii: sys_int_machine_t;               {scratch integer}
  r: real;                             {scratch floating point}
  stat: sys_err_t;                     {completion status}

label
  resize, redraw, next_event;

begin
{
*   Do one-time drawing initialization.
}
  rend_start;                          {start up RENDlib}
  rend_open (                          {create the RENDlib drawing device}
    string_v('right'(0)),              {device name}
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
{
*   Adjust to current drawing device size, which may have changed.
}
resize:
  rend_set.enter_rend^;
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
  {
  *   Set the text size.  Only the local copy of the text control state is set
  *   here.  Some state, like the anchor origin, is specific to the instance.
  *   The RENDlib text control state will be set anyway later before any text is
  *   drawn.
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

  rend_set.exit_rend^;
{
*   Redraw the whole display.
}
redraw:
  csvana_redraw;                       {redraw whole display with current parameters}
{
*   Handle events.
}
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
