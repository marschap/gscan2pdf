use warnings;
use strict;
use Test::More tests => 8;

BEGIN {
 use_ok('Gscan2pdf::NetPBM');
}

#########################

for (qw(pbm pgm ppm)) {
 my $file = "test.$_";
 system("convert -resize 8x5 rose: $file");
 is( Gscan2pdf::NetPBM::file_size_from_header($file),
  -s $file, "get_size_from_PNM $_ 8 wide" );
 system("convert -resize 9x6 rose: $file");
 is( Gscan2pdf::NetPBM::file_size_from_header($file),
  -s $file, "get_size_from_PNM $_ 9 wide" );
 unlink $file;
}

#########################

my $file = 'test.pnm';
system("touch $file");
is( Gscan2pdf::NetPBM::file_size_from_header($file), -s $file, "0-length PNM" );
unlink $file;

#########################

__END__
