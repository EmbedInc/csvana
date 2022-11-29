{   Program CSVANA csvfile
}
program csvana;
%include csvana.ins.pas;

var
  fnam:                                {CSV input file name}
    %include '(cog)lib/string_treename.ins.pas';
  root_p: csvana_root_p_t;             {to root CSV file data structure}
  stat: sys_err_t;                     {completion status}

begin
  string_cmline_init;                  {init for reading the command line}
  string_cmline_token (fnam, stat);    {get the CSV file name}
  sys_error_abort (stat, '', '', nil, 0);
  string_cmline_end_abort;             {no additional command line arguments allowed}

  csvana_read_file (                   {read the CSV file, save data in memory}
    fnam,                              {name of CSV file to read}
    util_top_mem_context,              {parent mem context, will create subordinate}
    root_p,                            {returned pointer to CSV file data}
    stat);
  sys_error_abort (stat, '', '', nil, 0);

  writeln ('CSV file "', root_p^.tnam.str:root_p^.tnam.len, '":');
  writeln ('  ', root_p^.nvals, ' dependent values');
  writeln ('  ', root_p^.nrec, ' data records');
  if root_p^.rec_last_p <> nil then begin
    string_f_fp_fixed (fnam, root_p^.rec_last_p^.time, 3);
    writeln ('  ', fnam.str:fnam.len, ' seconds of data');
    end;

  if
      (root_p^.nrec >= 2) and          {at least two records ?}
      (root_p^.rec_last_p^.time > root_p^.rec_p^.time) {there is a time difference ?}
      then begin
    csvana_draw (                      {show the data graphically}
      root_p^,                         {the data to show}
      root_p^.rec_p^.time,             {starting time to show}
      root_p^.rec_last_p^.time);       {ending time to show}
    end;
  end.
