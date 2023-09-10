{   Private include file for the ANASHOW program.
}
%include 'debug_switches.ins.pas';
%include 'sys.ins.pas';
%include 'util.ins.pas';
%include 'string.ins.pas';
%include 'file.ins.pas';
%include 'stuff.ins.pas';
%include 'vect.ins.pas';
%include 'img.ins.pas';
%include 'rend.ins.pas';
%include 'gui.ins.pas';
%include 'db25.ins.pas';
%include 'csvana.ins.pas';
%include 'dongsim.ins.pas';
%include 'builddate.ins.pas';

const
  minmeas = 0.01;                      {min meas interval as fraction of disp range}
  zoomf = 1.2;                         {auto zoom in/out size change factor}

type
  runend_k_t = (                       {ID for why run ended}
    runend_nstart_k,                   {not run, no starting record}
    runend_atend_k,                    {not run, at end of data}
    runend_atstop_k,                   {not run, already at ending record}
    runend_aftstop_k,                  {not run, start was after ending record}
    runend_stoprec_k,                  {ran, stopped at ending record}
    runend_diff_k,                     {ran, pins at different levels than driven}
    runend_end_k);                     {ran, stopped at end of data}

  runstop_k_t = (                      {reasons to stop run}
    runstop_diff_k);                   {stop if pins different from driven}
  runstop_t = set of runstop_k_t;      {all the stop reasons in one word}

var (anashow)
  {
  *   RENDlib configuration state.
  }
  devname: string_var80_t;             {RENDlib drawing device name}
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
  drlock: sys_sys_threadlock_t;        {single thread lock for drawing}
  evdrtask: sys_sys_event_id_t;        {drawing task pending, sig when DO_xxx set}
  do_resize: boolean;                  {need to adjust to graphics device size}
  do_redraw: boolean;                  {need to refresh drawing}
  do_tactiv: boolean;                  {need to update activity indicator}
  {
  *   Drawing configuration state.  This can change with the drawing area size.
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
  meas1, meas2: double;                {start/end measuring interval data time values}
  curs: double;                        {cursor data time value}
  tactiv: double;                      {time at which to show activity, <0 off}
  tactivx: sys_int_machine_t;          {2DIM X activity indicator curr drawn at}
  tactiv_drawn: boolean;               {activity indicator is currently drawn}
  {
  *   State for interacting with the DB-25 board and a dongle.
  }
  db25_p: db25_p_t;                    {to DB25 library use state}
  dongrec_p: csvana_rec_p_t;           {to current output state, may be NIL}
  {
  *   Dongle simulation state.
  }
  sim_p: dongsim_p_t;                  {points to DONGSIM library use state, if any}
  simrec_p: csvana_rec_p_t;            {to curr simulated dongle state, may be NIL}
{
*   Globally visible subroutines and functions.
}
procedure anashow_dataind (            {find which data indicator specified by X,Y}
  in      x, y: real;                  {2D space coordinate used to pick indicator}
  out     ind: csvana_ind_k_t);        {returned ID of indicator, NONE if no match}
  val_param; extern;

procedure anashow_datt_upd;            {sanitize and update data range control state}
  val_param; extern;

procedure anashow_do_redraw;           {cause drawing thread to redraw display}
  val_param; extern;

procedure anashow_do_resize;           {cause drawing thread to resize to display}
  val_param; extern;

procedure anashow_do_tactiv;           {cause activity indicator to be redrawn}
  val_param; extern;

procedure csvana_drag_cursor (         {drag data value cursor}
  in      key: rend_event_key_t;       {key press event to start drag}
  in out  redraw: boolean);            {will set to TRUE if redraw required}
  val_param; extern;

procedure anashow_draw;                {refresh the drawing area}
  val_param; extern;

procedure anashow_draw_tactiv;         {draw or erase activity indicator, as configured}
  val_param; extern;

procedure anashow_draw_enter;          {enter drawing mode, single threaded}
  val_param; extern;

procedure anashow_draw_leave;          {leave drawing mode, release single thread lock}
  val_param; extern;

procedure anashow_draw_resize;         {udpate to current drawing area size}
  val_param; extern;

procedure anashow_draw_run;            {start drawing, spawns drawing thread}
  val_param; extern;

procedure anashow_draw_setup;          {do one-time setup for drawing}
  val_param; extern;

procedure anashow_draw_thread (        {thread to do drawing in background}
  in      arg: sys_int_adr_t);         {arbitrary argument, unused}
  val_param; extern;

procedure anashow_events_setup;        {set up RENDlib events as we will use them}
  val_param; extern;

procedure anashow_events_thread (      {thread to handle graphics events}
  in      arg: sys_int_adr_t);         {arbitrary argument, unused}
  val_param; extern;

procedure anashow_pan (                {pan the display along the X axis}
  in      key: rend_event_key_t;       {key press event to start drag}
  in out  redraw: boolean);            {will set to TRUE if redraw required}
  val_param; extern;

procedure anashow_zoom (               {zoom in/out}
  in      zin: sys_int_machine_t;      {increments to zoom in, negative for zoom out}
  in      zx: double);                 {X data value to zoom about}
  val_param; extern;

function dattx (                       {make 2D X from data X value}
  in      t: double)                   {data independent variable value}
  :real;                               {returned 2D X coordinate}
  val_param; extern;

function datxt (                       {make data value X from 2D X}
  in      x: real)                     {2D X coordinate}
  :double;                             {corresponding data value X}
  val_param; extern;

procedure dong_close;                  {close connection to dongle, if open}
  val_param; extern;

procedure dong_conn;                   {make sure conn open, init to ON if closed}
  val_param; extern;

procedure dong_off;                    {turn off dongle, no power}
  val_param; extern;

procedure dong_on;                     {set up DB-25 for normal dongle operations}
  val_param; extern;

procedure dong_rec_curs;               {set data record to cursor pos, drive pins}
  val_param; extern;

procedure dong_rec_next;               {to next data record, drive pins accordingly}
  val_param; extern;

procedure dong_rec_set (               {set pins according to data record}
  in      rec_p: csvana_rec_p_t);      {pointer to data record, NIL for none}
  val_param; extern;

function dong_run (                    {run from current dongle record}
  in      stoprec_p: csvana_rec_p_t;   {record to stop at, run to end on NIL}
  in      runstop: runstop_t;          {optional additional stop criteria}
  out     diff: db25_pinmask_t)        {diff at end, if stop of diff requested}
  :runend_k_t;                         {reason run ended}
  val_param; extern;

procedure dong_show_driven;            {test pins, show which driven by dongle}
  val_param; extern;

procedure dong_show_pins;              {show pin states}
  val_param; extern;

procedure pix2d (                      {make 2D space coodinate from pixel coordinate}
  in    px, py: sys_int_machine_t;     {2DIMI (pixel space) coordinate}
  out   x, y: real);                   {same location in 2D space}
  val_param; extern;

procedure sim_init;                    {one-time initialize our sim-related state}
  val_param; extern;

procedure sim_rec (                    {update simulation to data record}
  in      rec_p: csvana_rec_p_t);      {to data record to update simulation with}
  val_param; extern;

procedure sim_rec_curs;                {reset sim, set to record at data cursor}
  val_param; extern;

procedure sim_rec_next;                {advance simulation to next record}
  val_param; extern;

procedure sim_reset;                   {reset simulated dongle state to idle}
  val_param; extern;

function sim_run (                     {run simulation from current position}
  in      stoprec_p: csvana_rec_p_t)   {record to stop at, run to end on NIL}
  :runend_k_t;                         {reason run ended}
  val_param; extern;

procedure sim_start;                   {make sure simulation is started and ready}
  val_param; extern;

procedure sim_stop;                    {stop dongle simulation, release resources}
  val_param; extern;
