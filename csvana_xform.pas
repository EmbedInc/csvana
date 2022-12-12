{   Coordinate transformations.
}
module csvana_xform;
define dattx;
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
