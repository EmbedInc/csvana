{   Coordinate transformations.
}
module csvana_xform;
define dattx;
define datxt;
define pix2d;
define csvana_dataind;
%include 'csvana.ins.pas';
{
********************************************************************************
*
*   Function DATTX (T)
*
*   Returns the X coordinate for the independent data variable value T.
}
function dattx (                       {make 2D X from data X value}
  in      t: double)                   {data independent variable value}
  :real;                               {returned 2D X coordinate}
  val_param;

begin
  dattx := ((t - datt1) * datdx / datdt) + datlx;
  end;
{
********************************************************************************
*
*   Function DATXT (X)
*
*   Returns the data X value corresponding to the 2D space X coordinate X.
}
function datxt (                       {make data value X from 2D X}
  in      x: real)                     {2D X coordinate}
  :double;                             {corresponding data value X}
  val_param;

begin
  datxt := ((x - datlx) * datdt / datdx) + datt1;
  end;
{
********************************************************************************
*
*   Subroutine PIX2D (PX, PY, X, Y)
*
*   Find the 2D space X,Y coordinate at the center of the pixel at PX,PY.  PX,PY
*   is in the 2DIMI space.
}
procedure pix2d (                      {make 2D space coodinate from pixel coordinate}
  in    px, py: sys_int_machine_t;     {2DIMI (pixel space) coordinate}
  out   x, y: real);                   {same location in 2D space}
  val_param;

var
  p2dim: vect_2d_t;                    {2DIM space coordinate}
  p2d: vect_2d_t;                      {2D space coordinate}

begin
  p2dim.x := px + 0.5;                 {make 2DIM coordinate from 2DIMI}
  p2dim.y := py + 0.5;

  rend_get.bxfpnt_2d^ (p2dim, p2d);    {transform 2DIM coordinate to 2D}

  x := p2d.x;                          {return 2D coordinate}
  y := p2d.y;
  end;
{
********************************************************************************
*
*   Subroutine CSVANA_DATAIND (X, Y, IND)
*
*   Find which data indicator is selected by the 2D space X,Y coordinate.  IND
*   is returned with the selected indicator ID, or NONE which means that X,Y is
*   not a valid data indicator selection coordinate.
}
procedure csvana_dataind (             {find which data indicator specified by X,Y}
  in      x, y: real;                  {2D space coordinate used to pick indicator}
  out     ind: csvana_ind_k_t);        {returned ID of indicator, NONE if no match}
  val_param;

var
  dx: real;                            {delta or offset in X}
  ylim: real;                          {Y coordinate limit}
  ofs: real;                           {offset}
  close: real;                         {X offset to best selection so far}

begin
  ind := csvana_ind_none_k;            {init to no indicator selected}
  dx := tparm.size * 0.30;             {allowed offset from marker X}

  if (x < datlx-dx) or (x > datrx+dx)  {outside displayed data range ?}
    then return;

  ylim := datv1y - (datvalh / 2.0);    {bottom of bottom data bar}
  if y >= ylim then begin              {in graph area, only select cursor here ?}
    ind := csvana_ind_curs_k;
    return;
    end;
{
*   The point is in the bottom label area.  Each data indicator can be selected
*   here, but the selection point must be within the rectangle around the marker
*   for the specific data indicator.  If within the marker area of multiple, the
*   closest one is selected.
}
  ylim := ylim - tparm.size * 0.6;     {min Y to hit markers}
  if y < ylim then return;             {too low to hit markers}

  close := dx * 2.0;                   {init to beyond selection distance}

  ofs := abs(x - dattx(meas1));        {check for measurement start selected}
  if (ofs <= dx) and (ofs < close) then begin
    close := ofs;
    ind := csvana_ind_st_k;
    end;

  ofs := abs(x - dattx(meas2));        {check for measurement end selected}
  if (ofs <= dx) and (ofs < close) then begin
    close := ofs;
    ind := csvana_ind_en_k;
    end;

  ofs := abs(x - dattx(curs));         {check for data cursor selected}
  if (ofs <= dx) and (ofs < close) then begin
    close := ofs;
    ind := csvana_ind_curs_k;
    end;
  end;
