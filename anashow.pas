{   Program CSVANA csvfile
}
program anashow;
define anashow;
%include anashow.ins.pas;

const
  max_msg_args = 2;                    {max arguments we can pass to a message}
  n_cmdnames_k = 10;                   {number of command names in the list}
  cmdname_maxchars_k = 7;              {max chars in any command name}

  cmdname_len_k = cmdname_maxchars_k + 1; {number of chars to reserve per cmd name}

type
  cmdname_t =                          {one command name in the list}
    array[1..cmdname_len_k] of char;
  cmdnames_t =                         {list of all the command names}
    array[1..n_cmdnames_k] of cmdname_t;

var
  cmdnames: cmdnames_t := [            {list of all the command names}
    'HELP   ',                         {1}
    '?      ',                         {2}
    'QUIT   ',                         {3}
    'Q      ',                         {4}
    'M      ',                         {5}
    'ON     ',                         {6}
    'OFF    ',                         {7}
    'R      ',                         {8}
    'DR     ',                         {9}
    'RD     ',                         {10}
    ];

var
  fnam:                                {CSV input file name}
    %include '(cog)lib/string_treename.ins.pas';
  prompt:                              {prompt string for entering command}
    %include '(cog)lib/string4.ins.pas';
  mask: db25_pinmask_t;                {scratch pins mask}
  iname_set: boolean;                  {TRUE if the input file name already set}
  tst_set, ten_set: boolean;           {start/end data time on command line}

  opt:                                 {upcased command line option}
    %include '(cog)lib/string_treename.ins.pas';
  parm:                                {command line option parameter}
    %include '(cog)lib/string_treename.ins.pas';
  pick: sys_int_machine_t;             {number of token picked from list}
  msg_parm:                            {references arguments passed to a message}
    array[1..max_msg_args] of sys_parm_msg_t;
  stat: sys_err_t;                     {completion status}

label
  next_opt, err_parm, parm_bad, done_opts,
  loop_cmd, done_cmd, err_extra, bad_cmd, bad_parm, err_cmparm, leave;

%include '(cog)lib/wout_local.ins.pas'; {define std out writing routines}
%include '(cog)lib/nextin_local.ins.pas'; {define command reading routines}
{
********************************************************************************
*
*   Start of main program.
}
begin
  devname.max := size_char(devname.str); {init RENDlib device name}
  devname.len := 0;
  db25_p := nil;                       {init to not connected to DB-25 board}
  dongrec_p := nil;                    {init to no current dongle data record}
  sim_init;                            {init simulated dongle state}
{
*   Initialize before reading the command line.
}
  string_cmline_init;                  {init for reading the command line}
  iname_set := false;                  {no input file name specified}
  tst_set := false;                    {init to data time limits not specified}
  ten_set := false;
{
*   Back here each new command line option.
}
next_opt:
  string_cmline_token (opt, stat);     {get next command line option name}
  if string_eos(stat) then goto done_opts; {exhausted command line ?}
  sys_error_abort (stat, 'string', 'cmline_opt_err', nil, 0);
  if (opt.len >= 1) and (opt.str[1] <> '-') then begin {implicit pathname token ?}
    if not iname_set then begin        {input file name not set yet ?}
      string_treename(opt, fnam);      {set input file name}
      iname_set := true;               {input file name is now set}
      goto next_opt;
      end;
    sys_msg_parm_vstr (msg_parm[1], opt);
    sys_message_bomb ('string', 'cmline_opt_conflict', msg_parm, 1);
    end;
  string_upcase (opt);                 {make upper case for matching list}
  string_tkpick80 (opt,                {pick command line option name from list}
    '-IN -DEV -ST -EN',
    pick);                             {number of keyword picked from list}
  case pick of                         {do routine for specific option}
{
*   -IN filename
}
1: begin
  if iname_set then begin              {input file name already set ?}
    sys_msg_parm_vstr (msg_parm[1], opt);
    sys_message_bomb ('string', 'cmline_opt_conflict', msg_parm, 1);
    end;
  string_cmline_token (opt, stat);
  string_treename (opt, fnam);
  iname_set := true;
  end;
{
*   -DEV name
}
2: begin
  string_cmline_token (devname, stat);
  end;
{
*   -ST
}
3: begin
  string_cmline_token_fp2 (datt1, stat);
  tst_set := true;
  end;
{
*  -EN
}
4: begin
  string_cmline_token_fp2 (datt2, stat);
  ten_set := true;
  end;
{
*   Unrecognized command line option.
}
otherwise
    string_cmline_opt_bad;             {unrecognized command line option}
    end;                               {end of command line option case statement}

err_parm:                              {jump here on error with parameter}
  string_cmline_parm_check (stat, opt); {check for bad command line option parameter}
  goto next_opt;                       {back for next command line option}

parm_bad:                              {jump here on got illegal parameter}
  string_cmline_reuse;                 {re-read last command line token next time}
  string_cmline_token (parm, stat);    {re-read the token for the bad parameter}
  sys_msg_parm_vstr (msg_parm[1], parm);
  sys_msg_parm_vstr (msg_parm[2], opt);
  sys_message_bomb ('string', 'cmline_parm_bad', msg_parm, 2);

done_opts:                             {done with all the command line options}
  if not iname_set then begin
    sys_message_bomb ('string', 'cmline_input_fnam_missing', nil, 0);
    end;
  wout_init;                           {init STDOUT writing routines}
{
*   Read the CSV file data into memory.
}
  csvana_read_file (                   {read the CSV file, save data in memory}
    fnam,                              {name of CSV file to read}
    util_top_mem_context,              {parent mem context, will create subordinate}
    csv_p,                             {returned pointer to CSV file data}
    stat);
  sys_error_abort (stat, '', '', nil, 0);

  writeln ('CSV file "', csv_p^.tnam.str:csv_p^.tnam.len, '":');
  writeln ('  ', csv_p^.nvals, ' dependent values');
  writeln ('  ', csv_p^.nrec, ' data records');
  if csv_p^.rec_last_p <> nil then begin
    string_f_fp_fixed (fnam, csv_p^.rec_last_p^.time, 3);
    writeln ('  ', fnam.str:fnam.len, ' seconds of data');
    end;
{
*   Start up the drawing thread.  The data will be drawn in the background.  The
*   drawing thread will respond to graphics events, and will keep running until
*   the drawing device is closed, or a specific close request is received from
*   the user.
}
  if
      (csv_p^.nrec >= 2) and           {at least two records ?}
      (csv_p^.rec_last_p^.time > csv_p^.rec_p^.time) {there is a time difference ?}
      then begin
    if not tst_set then begin          {start time not set on command line ?}
      datt1 := csv_p^.rec_p^.time;     {default to whole data start time}
      end;
    if not ten_set then begin          {end time not set on command line ?}
      datt2 := csv_p^.rec_last_p^.time; {default to whole data end time}
      end;
    meas1 := datt1;                    {init meas interval to full display range}
    meas2 := datt2;
    curs := (datt1 + datt2) / 2.0;     {init data cursor to middle of disp range}
    anashow_datt_upd;                  {update and sanitize data range control state}

    anashow_draw_setup;                {do one-time drawing setup}
    anashow_draw_run;                  {start background drawing}
    end;
{
*   Let the user enter commands at a command prompt.
}
  string_vstring (prompt, ': '(0), -1); {set command prompt string}

loop_cmd:
  sys_wait (0.100);
  lockout;
  string_prompt (prompt);              {prompt the user for a command}
  newline := false;                    {indicate STDOUT not at start of new line}
  unlockout;

  string_readin (inbuf);               {get command from the user}
  newline := true;                     {STDOUT now at start of line}
  p := 1;                              {init BUF parse index}
  while inbuf.str[p] = ' ' do begin    {scan forwards to the first non-blank}
    p := p + 1;
    end;
  next_keyw (opt, stat);               {extract command name into OPT}
  if string_eos(stat) then goto loop_cmd;
  if sys_error_check (stat, '', '', nil, 0) then begin
    goto loop_cmd;
    end;
  string_tkpick_s (                    {pick command name from list}
    opt, cmdnames, sizeof(cmdnames), pick);
  case pick of                         {which command is it}
{
**********
*
*   HELP
}
1, 2: begin
  if not_eos then goto err_extra;

  lockout;                             {acquire lock for writing to output}
  writeln;
  writeln ('HELP or ?      - Show this list of commands.');
  writeln ('M              - Get measurement interval and cursor values');
  writeln ('ON, OFF        - Dongle on or off');
  writeln ('R              - Read DB-25 pins');
  writeln ('DR             - Find which DB-25 pins driven by dongle');
  writeln ('RD             - Run until pins different from driven');

  writeln ('Q or QUIT      - Exit the program');

  writeln;
  writeln ('Pgup: zoom in, Shft-Pgup: zoom to meas interval');
  writeln ('Pgdn: zoom out, Shft-Pgdn: zoom out to all data');
  writeln ('Lft-butt click: set data cursor, Lft-butt drag: move cursors');
  writeln ('Mid-butt: pan, Scroll: zoom in/out');
  writeln ('Down-arr: dongle to cursor, Shft-down-arr: dongle to first rec');
  writeln ('Rit-arr: dongle to next rec, Up-arr: run to data cursor');
  writeln ('F1: set sim to curs, Shft-F1: set sim to start');
  writeln ('F2: single step sim, shft-F2: run sim to cursor');

  unlockout;                           {release lock for writing to output}
  end;
{
**********
*
*   QUIT
}
3, 4: begin
  if not_eos then goto err_extra;

  goto leave;
  end;
{
**********
*
*   M
}
5: begin
  if not_eos then goto err_extra;

  lockout;
  string_f_fp_eng (parm, meas1, 7, opt);
  write ('Measurement interval from ', parm.str:parm.len, ' ', opt.str:opt.len, 's to ');
  string_f_fp_eng (parm, meas2, 7, opt);
  write (parm.str:parm.len, ' ', opt.str:opt.len, 's, size ');
  string_f_fp_eng (parm, meas2 - meas1, 4, opt);
  writeln (parm.str:parm.len, ' ', opt.str:opt.len, 's');
  string_f_fp_eng (parm, curs, 7, opt);
  writeln ('Cursor at ', parm.str:parm.len, ' ', opt.str:opt.len, 's');
  unlockout;
  end;
{
**********
*
*   ON
*
*   Configure DB-25 pins for normal communication with the dongle.
}
6: begin
  if not_eos then goto err_extra;

  dong_conn;                           {make sure connection is open}
  dong_on;                             {dongle on}
  end;
{
**********
*
*   OFF
*
*   Configure DB-25 pins to turn off the dongle.  All pins will be digital I/O
*   driven low.
}
7: begin
  if not_eos then goto err_extra;

  dong_conn;                           {make sure connection is open}
  dong_off;                            {dongle off}
  end;
{
**********
*
*   R
*
*   Read pins, show drive and data state.
}
8: begin
  if not_eos then goto err_extra;

  dong_conn;                           {make sure connection is open}
  lockout;
  dong_show_pins;                      {show state of each pin}
  unlockout;
  end;
{
**********
*
*   DR
*
*   Find what pins are being driven by the dongle.  Digital I/O pins will be
*   toggled.
}
9: begin
  if not_eos then goto err_extra;

  dong_conn;                           {make sure connection is open}
  lockout;
  dong_show_driven;                    {test I/O pins, show which driven by dongle}
  unlockout;
  end;
{
**********
*
*   RD
*
*   Run from the current dongle record until the pins are found at different
*   levels than what the dongle is being driven to.
}
10: begin
  if not_eos then goto err_extra;

  if dongrec_p = nil then begin
    lockout;
    writeln ('Dongle not currently driven.');
    unlockout;
    goto done_cmd;
    end;

  case dong_run(nil, [runstop_diff_k], mask) of
runend_stoprec_k, runend_end_k: begin
      lockout;
      db25_show_pinhead;               {write pins label header}
      db25_show_drive (db25_p^);
      unlockout;
      anashow_do_redraw;
      end;
runend_diff_k: begin
      lockout;
      db25_show_pinhead;               {write pins label header}
      db25_show_drive (db25_p^);
      db25_show_pins (                 {show pin states}
        db25_p^.pins,                  {pin values to show}
        mask,                          {mask of pins to show}
        'Diff',                        {label for this line}
        '0', '1', ' ');                {values to show for low, high, masked off}
      unlockout;
      anashow_do_redraw;
      end;
    end;
  end;
{
**********
*
*   Unrecognized command name.
}
otherwise
    goto bad_cmd;
    end;

done_cmd:                              {done processing this command}
  if sys_error(stat) then goto err_cmparm;

  if not_eos then begin                {extraneous token after command ?}
err_extra:
    lockout;
    writeln ('Too many parameters for this command.');
    unlockout;
    end;
  goto loop_cmd;                       {back to process next command}

bad_cmd:                               {unrecognized or illegal command}
  lockout;
  writeln ('Huh?');
  unlockout;
  goto loop_cmd;

bad_parm:                              {bad parameter, parmeter in PARM}
  lockout;
  writeln ('Bad parameter "', parm.str:parm.len, '"');
  unlockout;
  goto loop_cmd;

err_cmparm:                            {parameter error, STAT set accordingly}
  lockout;
  sys_error_print (stat, '', '', nil, 0);
  unlockout;
  goto loop_cmd;

leave:
  dong_close;                          {close connection to the dongle, if open}
  end.
