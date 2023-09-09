{   Routines for simulating dongle internal state.
}
module anashow_sim;
define sim_init;
define sim_start;
define sim_reset;
define sim_stop;
define sim_rec;
define sim_rec_curs;
define sim_rec_next;
define sim_run;
%include anashow.ins.pas;

var
  pinnames: string                     {field names expected for sim pins}
    := 'D0 D1 D2 D3 D4 D5 D6 D7 BUSY';
{
********************************************************************************
*
*   Subroutine SIM_INIT
*
*   Initialize the simulated dongle state to none.  The simulated dongle state
*   is assumed to be uninitialized on entry.
}
procedure sim_init;                    {one-time initialize our sim-related state}
  val_param;

begin
  sim_p := nil;                        {indicate no simulated dongle state exists}
  simrec_p := nil;                     {no current simulated dongle record}
  end;
{
********************************************************************************
*
*   Subroutine SIM_START
*
*   Make sure simulated dongle state exists and is ready to use.  Nothing is
*   done if the state already exists.
}
procedure sim_start;                   {make sure simulation is started and ready}
  val_param;

var
  pnames: string_var80_t;              {list of pin names in var string}
  p: string_index_t;                   {pin names list parse index}
  pin: dongsim_pin_k_t;                {ID of current PIN}
  pname: string_var32_t;               {current pin name}
  ind: sys_int_machine_t;              {current data array 1-N index}
  name_p: csvana_name_p_t;             {to name for current data array index}
  stat: sys_err_t;                     {completion status}

begin
  pnames.max := size_char(pnames.str); {init local var strings}
  pname.max := size_char(pname.str);

  if sim_p <> nil then return;         {simulated dongle state already set up ?}

  if csv_p = nil then begin            {no CSV data exists ?}
    writeln ('INTERNAL ERROR: SIM_START called with no existing CSV data');
    sys_bomb;
    end;

  dongsim_lib_open (                   {create new use of the dongle simulator}
    csv_p^.mem_p^,                     {parent memory context}
    sim_p,                             {returned pointer to the new sim state}
    stat);                             {completion status}
  sys_error_abort (stat, '', '', nil, 0);
{
*   Fill in the SIM_FIELD array.  It gives the 1-N data array index for each of
*   our special known pins.
}
  string_vstring (pnames, pinnames, size_char(pinnames)); {make pin names var string}
  p := 1;                              {init pin names parse index}

  for pin := firstof(pin) to lastof(pin) do begin {loop over all special pins}
    string_token (pnames, p, pname, stat); {get name of this pin}
    sys_error_abort (stat, '', '', nil, 0);
    ind := 1;                          {init current index to check name of}
    name_p := csv_p^.name_p;           {point to name for this index}
    while name_p <> nil do begin       {scan the list of field names}
      if string_equal (name_p^.name, pname) then begin {found field for PIN ?}
        sim_field[pin] := ind;         {save 1-N index for this pin}
        exit;                          {found pin name, stop looking}
        end;
      name_p := name_p^.next_p;        {to next field name}
      ind := ind + 1;                  {update data index for this new field}
      end;                             {back to check new field for pin match}
    if name_p = nil then begin         {didn't find name of this pin ?}
      writeln;
      writeln ('Data set contains no field named "', pname.str:pname.len, '".');
      sys_bomb;
      end;
    end;                               {back for next special pin}

  simrec_p := nil;                     {init to not at a particular data record}
  end;
{
********************************************************************************
*
*   Subroutine SIM_RESET
*
*   Reset the simulated dongle state to idle.
}
procedure sim_reset;                   {reset simulated dongle state to idle}
  val_param;

begin
  sim_start;                           {make sure simulation has been started}
  dongsim_sim_reset (sim_p^);          {reset the simulated dongle state}
  simrec_p := nil;                     {sim not at a particular data record}
  end;
{
********************************************************************************
*
*   Subroutine SIM_STOP
*
*   Stop simulating dongle internal state.  Any resources allocated to the
*   simulation are released.
}
procedure sim_stop;                    {stop dongle simulation, release resources}
  val_param;

var
  stat: sys_err_t;                     {completion status}

begin
  if sim_p = nil then return;          {no simulation state, nothing to do ?}

  dongsim_lib_close (sim_p, stat);     {end simulation, deallocate resources}
  sys_error_abort (stat, '', '', nil, 0);

  simrec_p := nil;                     {sim not at a particular data record}
  end;
{
********************************************************************************
*
*   Subroutine SIM_REC (REC_P)
*
*   Update the simulated dongle state to the pin leves indicated by the data
*   record at REC_P.  REC_P may be NIL, in which case nothing is done.
}
procedure sim_rec (                    {update simulation to data record}
  in      rec_p: csvana_rec_p_t);      {to data record to update simulation with}
  val_param;

var
  pins: dongsim_pins_t;                {dongle pins state}
  pin: dongsim_pin_k_t;                {ID for current pin}
  desc: string_var80_t;                {simulated state description string}

begin
  desc.max := size_char(desc.str);     {init local var string}

  if                                   {reset simulated state if not continuing}
      (simrec_p = nil) or else         {no current simulated position ?}
      (rec_p <> simrec_p^.next_p)      {new record not next from curr position ?}
      then begin
    sim_reset;                         {reset the simulated dongle state}
    end;

  simrec_p := rec_p;                   {save simulation position within dataset}
  if rec_p = nil then return;          {no record, nothing to simulate ?}
  tactiv := rec_p^.time;               {set data time of activity indicator}
  anashow_do_tactiv;                   {make sure activity indicator is updated}

  pins := [];                          {init all pin levels to low}
  for pin := firstof(pin) to lastof(pin) do begin {get pin states into PINS}
    if rec_p^.data[sim_field[pin]] <> 0 then begin {this pin is set ?}
      pins := pins + [pin];            {indicate this pin is high}
      end;
    end;

  dongsim_sim_pins (                   {update simulation with new pins state}
    sim_p^,                            {simulation state to update}
    pins,                              {new pins state to update it with}
    rec_p^.time,                       {data time of this new pins state}
    desc);                             {possible returned new state description}

  if desc.len > 0 then begin           {new state has description ?}
    writeln (desc.str:desc.len);       {show new simulated state description}
    end;
  end;
{
********************************************************************************
*
*   Subroutine SIM_REC_CURS
*
*   Set the simulated dongle state position to the data record indicated by the
*   data cursor.  The simulated state is reset before this is done.
}
procedure sim_rec_curs;
  val_param;

begin
  simrec_p := nil;                     {reset to no current sim in progress}
  sim_rec ( csvana_datt_rec(curs) );   {set sim to data record at cursor, if any}
  end;
{
********************************************************************************
*
*   Subroutine SIM_REC_NEXT
*
*   Advance to the simulation to the next data record.  Nothing is done if there
*   is no current simulation record, or there is no next record.
}
procedure sim_rec_next;
  val_param;

begin
  if simrec_p = nil then return;       {no current simulation position ?}
  if simrec_p^.next_p = nil then return; {no next record ?}
  sim_rec (simrec_p^.next_p);          {advance simulation to the next record}
  end;
{
********************************************************************************
*
*   Function SIM_RUN (STOPREC_P)
*
*   Run the dongle simulation from the current record to that pointed to by
*   STOPREC_P.  When STOPREC_P is NIL, then the simulation is run to the end of
*   the data.
}
function sim_run (                     {run simulation from current position}
  in      stoprec_p: csvana_rec_p_t)   {record to stop at, run to end on NIL}
  :runend_k_t;                         {reason run ended}
  val_param;

begin
  if simrec_p = nil then begin         {check for no starting record}
    sim_run := runend_nstart_k;
    return;
    end;

  if simrec_p^.next_p = nil then begin {check for at last record}
    sim_run := runend_atend_k;
    return;
    end;

  if stoprec_p <> nil then begin       {ending record specified ?}
    if simrec_p = stoprec_p then begin {already at the record to stop at ?}
      sim_run := runend_atstop_k;
      return;
      end;
    if simrec_p^.time > stoprec_p^.time then begin {after ending record ?}
      sim_run := runend_aftstop_k;
      return;
      end;
    end;

  sim_start;                           {make sure simulation started and ready}

  while true do begin                  {run over successive records}
    sim_rec_next;                      {to next record}
    if simrec_p = stoprec_p then begin {hit record to stop at ?}
      sim_run := runend_stoprec_k;     {indicate stop reason}
      return;
      end;
    if simrec_p^.next_p = nil then begin {at last record in data set ?}
      sim_run := runend_end_k;         {indicate stop reason}
      return;
      end;
    end;                               {back to advance to next data record}
  end;
