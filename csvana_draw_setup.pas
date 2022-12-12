{   Drawing setup.
}
module csvana_draw_setup;
define csvana_draw_setup;
define csvana_draw_run;
%include 'csvana.ins.pas';
{
********************************************************************************
*
*   Subroutine CSVANA_DRAW_SETUP
*
*   Do all the one-time drawing setup.
}
procedure csvana_draw_setup;           {do one-time setup for drawing}
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
  end;
{
********************************************************************************
*
*   Subroutine CSVANA_DRAW_RUN
*
*   Start the background thread to draw the CSV data.
*
*   This routine only launches the background drawing task and returns quickly.
}
procedure csvana_draw_run;             {start drawing, spawns drawing thread}
  val_param;

var
  thid: sys_sys_thread_id_t;           {ID of drawing thread}
  stat: sys_err_t;                     {completion status}

begin
  sys_thread_create (                  {start the drawing thread}
    addr(csvana_draw_thread),          {pointer to root thread routine}
    0,                                 {argument passed to thread, not used}
    thid,                              {returned thread ID}
    stat);
  sys_error_abort (stat, '', '', nil, 0);
  end;
