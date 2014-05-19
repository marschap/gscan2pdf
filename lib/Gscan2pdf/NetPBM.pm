package Gscan2pdf::NetPBM;

use strict;
use warnings;
use Readonly;
Readonly my $BINARY_BITMAP           => 4;
Readonly my $BINARY_GRAYMAP          => 5;
Readonly my $BITS_PER_BYTE           => 8;
Readonly my $BITMAP_BYTES_PER_PIXEL  => 1 / $BITS_PER_BYTE;
Readonly my $GRAYMAP_BYTES_PER_PIXEL => 1;
Readonly my $PIXMAP_BYTES_PER_PIXEL  => 3;

our $VERSION = '1.2.5';

# Return file size expected by PNM header

sub file_size_from_header {
    my $filename = shift;

    open my $fh, '<', $filename or return 0;
    my $header = <$fh>;
    my $magic_value;
    if ( defined($header) and $header =~ /^P(\d)\n/xsm ) {
        $magic_value = $1;
    }
    else {
        close $fh or return 0;
        return 0;
    }
    if ( $magic_value < $BINARY_BITMAP ) {
        close $fh or return 0;
        return 0;
    }
    my $line = <$fh>;
    $header .= $line;
    while ( $line =~ /^(\#|\s*\n)/xsm ) {
        $line = <$fh>;
        $header .= $line;
    }
    if ( $line =~ /(\d*)\ (\d*)\n/xsm ) {
        my ( $width, $height ) = ( $1, $2 );
        if ( $magic_value == $BINARY_BITMAP ) {
            my $mod = $width % $BITS_PER_BYTE;
            if ( $mod > 0 ) { $width += $BITS_PER_BYTE - $mod }
        }
        my $datasize = $width * $height * (
            $magic_value == $BINARY_BITMAP ? $BITMAP_BYTES_PER_PIXEL
            : (
                  $magic_value == $BINARY_GRAYMAP ? $GRAYMAP_BYTES_PER_PIXEL
                : $PIXMAP_BYTES_PER_PIXEL
            )
        );
        if ( $magic_value > $BINARY_BITMAP ) {
            $line = <$fh>;
            $header .= $line;
        }
        close $fh or return 0;
        return length($header) + $datasize;
    }
    else {
        close $fh or return 0;
        return 0;
    }
}

1;

__END__
