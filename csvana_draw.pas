{   Drawing routines.  The drawing state is kept internal to this module.
}
module csvana_draw;
define csvana_draw;
%include 'csvana.ins.pas';
%include 'vect.ins.pas';
%include 'img.ins.pas';
%include 'rend.ins.pas';

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
  rend_get.vect_parms^ (vparm);
  rend_get.poly_parms^ (pparm);

  rend_get.clip_2dim_handle^ (cliph);  {create 2DIM clip window, get handle}

  rend_set.update_mode^ (rend_updmode_buffall_k);
  rend_set.exit_rend^;
{
*   Adjust to current drawing device size, which may have changed.
}
resize:
  rend_set.enter_rend^;
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

  rend_set.exit_rend^;
{
*   Redraw the whole display.
}
redraw:
  rend_set.enter_rend^;

  rend_set.rgb^ (0.2, 0.2, 0.2);
  rend_prim.clear_cwind^;

  rend_set.rgb^ (0.8, 0.8, 0.8);
  rend_set.cpnt_2dim^ (devdx, devdy/2);
  rend_prim.vect_2dimcl^ (devdx/2, 0);
  rend_prim.vect_2dimcl^ (0, devdy/2);
  rend_prim.vect_2dimcl^ (devdx/2, devdy);
  rend_prim.vect_2dimcl^ (devdx, devdy/2);

  rend_set.exit_rend^;
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
