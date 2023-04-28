{   Routines for communicating with the DB-25 hardware and the dongle.
}
module csvana_dong;
define dong_conn;
define dong_close;
define dong_on;
define dong_off;
define dong_show_pins;
define dong_show_driven;
define dong_rec_set;
define dong_rec_curs;
define dong_rec_next;
%include csvana.ins.pas;

const
  clk_pin = 9;                         {clock line pin number}

var
  pins_io: db25_pinmask_t;             {mask of bi-directional I/O pins}
{
********************************************************************************
*
*   Local subroutine SETPIN (PIN, DR)
*
*   Set the pin PIN to the drive DR.
}
procedure setpin (                     {configure a pin}
  in      pin: sys_int_machine_t;      {1-N pin number}
  in      dr: db25_pindr_k_t);         {drive to configure for this pin}
  val_param; internal;

var
  mask: db25_pinmask_t;                {mask for the selected pin}
  stat: sys_err_t;                     {completion status}

begin
  db25_cmd_pin (db25_p^, pin, dr, stat); {set the pin drive type}
  sys_error_abort (stat, '', '', nil, 0);

  mask := db25_pin_mask(pin);          {make mask for the selected pin}
  case dr of                           {what drive type is this ?}
db25_pindr_lo_k, db25_pindr_hi_k: begin {digital I/O}
      pins_io := pins_io ! mask;
      end;
db25_pindr_gnd_k, db25_pindr_pwr_k: begin {fixed ground or power}
      pins_io := pins_io & ~mask;
      end;
    end;
  end;
{
********************************************************************************
*
*   Subroutine DONG_CONN
*
*   Ensure that the connection to the dongle is open.  If the connection is not
*   already open, then it is opened and the DB-25 pins set up for normal dongle
*   operations.  After this call, DB25_P is guaranteed to be a valid pointer.
}
procedure dong_conn;                   {make sure conn open, init to ON if closed}
  val_param;

var
  stat: sys_err_t;                     {completion status}

begin
  if db25_p <> nil then return;        {the connection is already open ?}

  db25_lib_new (                       {open connection to the DB25 hardware}
    util_top_mem_context,              {parent mem context, will make child}
    db25_p,                            {returned pointer to new DB25 lib state}
    stat);
  sys_error_abort (stat, '', '', nil, 0);

  dong_on;                             {set up pins for communication with dongle}
  end;
{
********************************************************************************
*
*   Subroutine DONG_CLOSE
*
*   Make sure the connection to the dongle is closed and associated resources
*   deallocated.  Nothing is done if the connection to the dongle is not open.
}
procedure dong_close;                  {close connection to dongle, if open}
  val_param;

var
  stat: sys_err_t;                     {completion status}

begin
  if db25_p = nil then return;         {connection not open, nothing to do ?}

  db25_lib_end (db25_p, stat);         {close the connection, deallocate resources}
  sys_error_abort (stat, '', '', nil, 0);
  end;
{
********************************************************************************
*
*   Subroutine DONG_ON
*
*   Set up the DB-25 pins for normal communication with the dongle.
}
procedure dong_on;                     {set up DB-25 for normal dongle operations}
  val_param;

var
  stat: sys_err_t;                     {completion status}

begin
  pins_io := 0;                        {init mask of bi-directional I/O pins}

  setpin (1, db25_pindr_pwr_k);
  setpin (2, db25_pindr_lo_k);
  setpin (3, db25_pindr_lo_k);
  setpin (4, db25_pindr_lo_k);
  setpin (5, db25_pindr_lo_k);
  setpin (6, db25_pindr_lo_k);
  setpin (7, db25_pindr_lo_k);
  setpin (8, db25_pindr_lo_k);
  setpin (9, db25_pindr_lo_k);
  setpin (10, db25_pindr_gnd_k);
  setpin (11, db25_pindr_lo_k);
  setpin (12, db25_pindr_gnd_k);
  setpin (13, db25_pindr_gnd_k);
  setpin (14, db25_pindr_lo_k);
  setpin (15, db25_pindr_lo_k);
  setpin (16, db25_pindr_pwr_k);
  setpin (17, db25_pindr_lo_k);
  setpin (18, db25_pindr_lo_k);
  setpin (19, db25_pindr_gnd_k);
  setpin (20, db25_pindr_gnd_k);
  setpin (21, db25_pindr_gnd_k);
  setpin (22, db25_pindr_gnd_k);
  setpin (23, db25_pindr_gnd_k);
  setpin (24, db25_pindr_gnd_k);
  setpin (25, db25_pindr_lo_k);

  pins_io := pins_io & ~db25_pin_mask(clk_pin); {output-only clock}

  db25_cmd_pinupd (db25_p^, stat);     {update all pins to their new drive states}
  sys_error_abort (stat, '', '', nil, 0);
  end;
{
********************************************************************************
*
*   Subroutine DONG_OFF
*
*   Set up the DB-25 pins so that the dongle is off.  All pins are configured
*   for digital I/O and driven low.
}
procedure dong_off;                    {turn off dongle, no power}
  val_param;

var
  stat: sys_err_t;                     {completion status}

begin
  setpin (1, db25_pindr_lo_k);
  setpin (2, db25_pindr_lo_k);
  setpin (3, db25_pindr_lo_k);
  setpin (4, db25_pindr_lo_k);
  setpin (5, db25_pindr_lo_k);
  setpin (6, db25_pindr_lo_k);
  setpin (7, db25_pindr_lo_k);
  setpin (8, db25_pindr_lo_k);
  setpin (9, db25_pindr_lo_k);
  setpin (10, db25_pindr_lo_k);
  setpin (11, db25_pindr_lo_k);
  setpin (12, db25_pindr_lo_k);
  setpin (13, db25_pindr_lo_k);
  setpin (14, db25_pindr_lo_k);
  setpin (15, db25_pindr_lo_k);
  setpin (16, db25_pindr_lo_k);
  setpin (17, db25_pindr_lo_k);
  setpin (18, db25_pindr_lo_k);
  setpin (19, db25_pindr_lo_k);
  setpin (20, db25_pindr_lo_k);
  setpin (21, db25_pindr_lo_k);
  setpin (22, db25_pindr_lo_k);
  setpin (23, db25_pindr_lo_k);
  setpin (24, db25_pindr_lo_k);
  setpin (25, db25_pindr_lo_k);

  db25_cmd_pinupd (db25_p^, stat);     {update all pins to their new drive states}
  sys_error_abort (stat, '', '', nil, 0);
  end;
{
********************************************************************************
*
*   Subroutine DONG_SHOW_PINS
*
*   Show the current state of all the dongle pins.
}
procedure dong_show_pins;              {show pin states}
  val_param;

begin
  db25_show_hdrdat (db25_p^);          {read, show state}
  end;
{
********************************************************************************
*
*   Subroutine DONG_SHOW_DRIVEN
*
*   Test all I/O pins, then show which are driven by the dongle.
}
procedure dong_show_driven;            {test pins, show which driven by dongle}
  val_param;

var
  pins: db25_pinmask_t;                {scratch pins state mask}
  stat: sys_err_t;                     {completion status}

begin
  db25_pins_driven (                   {test pins for being externally driven}
    db25_p^,                           {state for this use of the DB25 library}
    pins_io,                           {mask of pins to check}
    pins,                              {returned mask of externally driven pins}
    stat);
  sys_error_abort (stat, '', '', nil, 0);

  db25_show_hdrdat (db25_p^);          {write header, drive state, digital values}
  db25_show_exdriven (pins, pins_io);  {show which pins are externally driven}
  end;
{
********************************************************************************
*
*   Subroutine DONG_REC_SET (REC)
*
*   Drive the pins according to the data record REC.  A pointer to the record is
*   saved in DONGREC_P to record which record is being driven onto the pins.
}
procedure dong_rec_set (               {set pins according to data record}
  in var  rec: csvana_rec_t);          {data record to drive on pins}
  val_param;

var
  name_p: csvana_name_p_t;             {points to current dependent variable name}
  vn: sys_int_machine_t;               {1-N number of current dependent variable}
  pin: sys_int_machine_t;              {pin number for this dependent variable}
  mask: db25_pinmask_t;                {mask for the current pin}
  pins: db25_pinmask_t;                {new pins state from this record}
  stat: sys_err_t;                     {completion status}

label
  next_dp;

begin
  dongrec_p := addr(rec);              {save what record dongle being driven with}

  pins := 0;                           {init all logic levels to low}
  vn := 1;                             {init number of current dependent variable}
  name_p := csv_p^.name_p;             {point to name of first field}

  while name_p <> nil do begin         {scan the list of dependent variables}
    string_t_int (name_p^.name, pin, stat); {get pin number from name}
    sys_error_abort (stat, '', '', nil, 0);
    mask := db25_pin_mask (pin);       {make mask for this pin}
    if rec.data[vn] <> 0 then begin    {this variable not set to 0 ?}
      pins := pins ! mask;             {set this pin to logic high}
      end;
next_dp:                               {done with this dependent var, on to next}
    name_p := name_p^.next_p;          {to name of next variable}
    vn := vn + 1;                      {update 1-N number of this variable}
    end;                               {back to process this new variable}

  db25_pins_set (db25_p^, pins, stat); {set pins to their new states}
  sys_error_abort (stat, '', '', nil, 0);
  end;
{
********************************************************************************
*
*   Subroutine DONG_REC_CURS
*
*   Set the current dongle data record to that indicated by the data cursor.
*   The pins will be driven according to the data in that record.
}
procedure dong_rec_curs;               {set data record to cursor pos, drive pins}
  val_param;

var
  rec_p: csvana_rec_p_t;               {pointer to current data record}

begin
  rec_p := csv_p^.rec_p;               {init to first record in data set}
  while rec_p <> nil do begin          {scan the records sequentially}
    if                                 {this is the record indicated by cursor ?}
        (rec_p^.next_p = nil) or else  {there is no subsequent record ?}
        (curs < rec_p^.next_p^.time)   {cursor is before the next record ?}
        then begin
      dong_rec_set (rec_p^);           {set dongle to this data record}
      return;
      end;
    rec_p := rec_p^.next_p;            {advance to next record in data set}
    end;                               {back to check this new record}

  dongrec_p := nil;                    {cursor is not at a data record}
  end;
{
********************************************************************************
*
*   Subroutine DONG_REC_NEXT
*
*   Advance to the next data record and drive the pins accordingly.  Nothing is
*   done if there is no current dongle data record, or there is not subsequent
*   data record.
}
procedure dong_rec_next;               {to next data record, drive pins accordingly}
  val_param;

begin
  if dongrec_p = nil then return;      {no current dongle record ?}
  if dongrec_p^.next_p = nil then return; {no subsequent record ?}

  dong_rec_set (dongrec_p^.next_p^);   {set dongle state to the next record}
  end;
