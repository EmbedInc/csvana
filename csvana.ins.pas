{   Private include file for the CSVANA program.
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
%include 'builddate.ins.pas';

const
  minmeas = 0.01;                      {min meas interval as fraction of disp range}
  zoomf = 1.2;                         {auto zoom in/out size change factor}

type
  csvana_name_p_t = ^csvana_name_t;
  csvana_name_t = record               {name of one field}
    next_p: csvana_name_p_t;           {to next field name}
    name: string_var4_t;               {field name, allocated to actual name length}
    end;

  csvana_data_t =                      {dependent data values for one record}
    array[1..1] of int8u_t;

  csvana_rec_p_t = ^csvana_rec_t;
  csvana_rec_t = record                {one CSV file record}
    prev_p: csvana_rec_p_t;            {to previous record, NIL at first}
    next_p: csvana_rec_p_t;            {to next record, NIL at last}
    time: double;                      {seconds offset from first record}
    data: csvana_data_t;               {dependent data values this record}
    end;

  csvana_root_p_t = ^csvana_root_t;
  csvana_root_t = record               {root information about logic analyzer CSV file}
    mem_p: util_mem_context_p_t;       {context for all dynamic memory this CSV file}
    tnam: string_treename_t;           {full treename to source file, if any}
    nvals: sys_int_machine_t;          {number of dependent values in each record}
    name_p: csvana_name_p_t;           {to first name in list of field names}
    name_last_p: csvana_name_p_t;      {to last name in list of field names}
    time0: sys_clock_t;                {absolute time of first record}
    nrec: sys_int_machine_t;           {number of records in the list}
    rec_p: csvana_rec_p_t;             {to list of data records}
    rec_last_p: csvana_rec_p_t;        {to last record in list}
    end;

  csvana_ind_k_t = (                   {IDs for the different data value indicators}
    csvana_ind_none_k,                 {no data value indicator selected}
    csvana_ind_st_k,                   {measurement interval start}
    csvana_ind_en_k,                   {measurement interval end}
    csvana_ind_curs_k);                {data cursor}

var (csvana)
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
  meas1, meas2: double;                {start/end measuring interval data values}
  curs: double;                        {cursor data value}
  {
  *   State for interacting with the DB-25 board and a dongle.
  }
  db25_p: db25_p_t;                    {to DB25 library use state}

{
*   Globally visible subroutines and functions.
}
procedure csvana_dataind (             {find which data indicator specified by X,Y}
  in      x, y: real;                  {2D space coordinate used to pick indicator}
  out     ind: csvana_ind_k_t);        {returned ID of indicator, NONE if no match}
  val_param; extern;

procedure csvana_datt_upd;             {sanitize and update data range control state}
  val_param; extern;

procedure csvana_do_redraw;            {cause drawing thread to redraw display}
  val_param; extern;

procedure csvana_do_resize;            {cause drawing thread to resize to display}
  val_param; extern;

procedure csvana_drag_cursor (         {drag data value cursor}
  in      key: rend_event_key_t;       {key press event to start drag}
  in out  redraw: boolean);            {will set to TRUE if redraw required}
  val_param; extern;

procedure csvana_draw;                 {refresh the drawing area}
  val_param; extern;

procedure csvana_draw_enter;           {enter drawing mode, single threaded}
  val_param; extern;

procedure csvana_draw_leave;           {leave drawing mode, release single thread lock}
  val_param; extern;

procedure csvana_draw_resize;          {udpate to current drawing area size}
  val_param; extern;

procedure csvana_draw_run;             {start drawing, spawns drawing thread}
  val_param; extern;

procedure csvana_draw_setup;           {do one-time setup for drawing}
  val_param; extern;

procedure csvana_draw_thread (         {thread to do drawing in background}
  in      arg: sys_int_adr_t);         {arbitrary argument, unused}
  val_param; extern;

procedure csvana_events_setup;         {set up RENDlib events as we will use them}
  val_param; extern;

procedure csvana_events_thread (       {thread to handle graphics events}
  in      arg: sys_int_adr_t);         {arbitrary argument, unused}
  val_param; extern;

procedure csvana_field_new (           {add new field per record to CSV data}
  in out  root: csvana_root_t;         {CSV data to add field to}
  in      name: univ string_var_arg_t); {name of the new field}
  val_param; extern;

procedure csvana_pan (                 {pan the display along the X axis}
  in      key: rend_event_key_t;       {key press event to start drag}
  in out  redraw: boolean);            {will set to TRUE if redraw required}
  val_param; extern;

procedure csvana_read_file (           {read logic analyzer CSV file, save data}
  in      fnam: univ string_var_arg_t; {name of CSV file to read, ".csv" suffix implied}
  in out  mem: util_mem_context_t;     {parent mem context, will create subordinate}
  out     root_p: csvana_root_p_t;     {returned pointer to CSV file data}
  out     stat: sys_err_t);            {returned completion status}
  val_param; extern;

procedure csvana_read_rec (            {read line from CSV file, add as record}
  in out  cin: csv_in_t;               {CSV file reading stat}
  in out  root: csvana_root_t;         {root structure for data from this CSV file}
  out     stat: sys_err_t);            {returned completion status}
  val_param; extern;

procedure csvana_rec_new (             {alloc and init new CSV file data record}
  in out  root: csvana_root_t;         {CSV file data to add recrod to}
  out     rec_p: csvana_rec_p_t);      {to new record, will be last in CSV file data}
  val_param; extern;

procedure csvana_root_del (            {delete all data for a CSV file}
  in out  root_p: csvana_root_p_t);    {to root data structure, returned NIL}
  val_param; extern;

procedure csvana_root_new (            {allocate and init new root CSV file data}
  in out  mem: util_mem_context_t;     {parent mem context, will create subordinate}
  out     root_p: csvana_root_p_t);    {to returned initialized root data structure}
  val_param; extern;

procedure csvana_zoom (                {zoom in/out}
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

procedure dong_conn;                   {make sure conn open, dongle on}
  val_param; extern;

procedure dong_off;                    {turn off dongle, no power}
  val_param; extern;

procedure dong_on;                     {set up DB-25 for normal dongle operations}
  val_param; extern;

procedure dong_show_driven;            {test pins, show which driven by dongle}
  val_param; extern;

procedure dong_show_pins;              {show pin states}
  val_param; extern;

procedure pix2d (                      {make 2D space coodinate from pixel coordinate}
  in    px, py: sys_int_machine_t;     {2DIMI (pixel space) coordinate}
  out   x, y: real);                   {same location in 2D space}
  val_param; extern;
