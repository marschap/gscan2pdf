package Gscan2pdf::NetPBM;

use strict;
use warnings;

# Return file size expected by PNM header

sub file_size_from_header {
 my $filename = shift;

 open my $fh, '<', $filename or return 0;
 my $header = <$fh>;
 my $magic_value;
 if ( $header =~ /^P(\d*)\n/x ) {
  $magic_value = $1;
 }
 else {
  close $fh;
  return 0;
 }
 if ( $magic_value < 4 ) {
  close $fh;
  return 0;
 }
 my $line = <$fh>;
 $header .= $line;
 while ( $line =~ /^(\#|\s*\n)/x ) {
  $line = <$fh>;
  $header .= $line;
 }
 if ( $line =~ /(\d*)\ (\d*)\n/x ) {
  my ( $width, $height ) = ( $1, $2 );
  if ( $magic_value == 4 ) {
   my $mod = $width % 8;
   $width += 8 - $mod if ( $mod > 0 );
  }
  my $datasize = $width * $height *
    ( $magic_value == 4 ? 1 / 8 : ( $magic_value == 5 ? 1 : 3 ) );
  if ( $magic_value > 4 ) {
   $line = <$fh>;
   $header .= $line;
  }
  close $fh;
  return length($header) + $datasize;
 }
 else {
  close $fh;
  return 0;
 }
}

1;

__END__
