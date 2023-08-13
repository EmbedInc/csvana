{   Drawing setup.
}
module anashow_draw_setup;
define anashow_draw_setup;
define anashow_draw_run;
define anashow_draw_enter;
define anashow_draw_leave;
%include 'anashow.ins.pas';
{
********************************************************************************
*
*   Subroutine ANASHOW_DRAW_SETUP
*
*   Do all the one-time drawing setup.
}
procedure anashow_draw_setup;          {do one-time setup for drawing}
  val_param;

var
  stat: sys_err_t;                     {completion status}

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
  vparm.subpixel := false;
  rend_set.vect_parms^ (vparm);

  rend_get.poly_parms^ (pparm);
  pparm.subpixel := true;
  rend_set.poly_parms^ (pparm);

  rend_get.clip_2dim_handle^ (cliph);  {create 2DIM clip window, get handle}

  rend_set.min_bits_vis^ (24.0);       {try for high color resolution}
  rend_set.update_mode^ (rend_updmode_buffall_k);
  szmem_p := nil;                      {init to no mem context for current size}
  anashow_events_setup;                {set up RENDlib events}
  rend_set.exit_rend^;

  sys_thread_lock_create (drlock, stat); {create mutex for drawing}
  sys_error_abort (stat, '', '', nil, 0);

  sys_event_create_bool (evdrtask);    {create event for new DO_xxx task pending}
  do_resize := true;                   {will require adjustment to drawing size}
  do_redraw := true;                   {will need to be drawn}

  tactiv := -1.0;                      {init activity indicator to off}
  tactiv_drawn := false;
  end;
{
********************************************************************************
*
*   Subroutine ANASHOW_DRAW_RUN
*
*   Start the background thread to draw the CSV data.
*
*   This routine only launches the background drawing task and returns quickly.
}
procedure anashow_draw_run;            {start drawing, spawns drawing thread}
  val_param;

var
  thid: sys_sys_thread_id_t;           {ID of drawing thread}
  stat: sys_err_t;                     {completion status}

begin
  sys_thread_create (                  {start the drawing thread}
    addr(anashow_draw_thread),         {pointer to root thread routine}
    0,                                 {argument passed to thread, not used}
    thid,                              {returned thread ID}
    stat);
  sys_error_abort (stat, '', '', nil, 0);

  sys_thread_create (                  {start events handling}
    addr(anashow_events_thread),       {pointer to root thread routine}
    0,                                 {argument passed to thread, not used}
    thid,                              {returned thread ID}
    stat);
  sys_error_abort (stat, '', '', nil, 0);
  end;
{
********************************************************************************
*
*   Subroutine ANASHOW_DRAW_ENTER
*
*   Acquire the drawing lock and enter RENDlib drawing mode.
}
procedure anashow_draw_enter;          {enter drawing mode, single threaded}
  val_param;

begin
  sys_thread_lock_enter (drlock);      {acquire exclusive lock on drawing}
  rend_set.enter_rend^;                {enter RENDlib drawing mode}
  end;
{
********************************************************************************
*
*   Subroutine ANASHOW_DRAW_LEAVE
*
*   Exit RENDlib drawing mode and release the drawing lock.
}
procedure anashow_draw_leave;          {leave drawing mode, release single thread lock}
  val_param;

begin
  rend_set.exit_rend^;                 {leave RENDlib drawing mode}
  sys_thread_lock_leave (drlock);      {release the drawing lock}
  end;
