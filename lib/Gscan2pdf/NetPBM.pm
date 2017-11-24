package Gscan2pdf::NetPBM;

use strict;
use warnings;
use Readonly;
Readonly my $BINARY_BITMAP          => 4;
Readonly my $BINARY_GRAYMAP         => 5;
Readonly my $BITS_PER_BYTE          => 8;
Readonly my $BITMAP_BYTES_PER_PIXEL => 1 / $BITS_PER_BYTE;
Readonly my $GRAYMAP_CHANNELS       => 1;
Readonly my $PIXMAP_CHANNELS        => 3;

our $VERSION = '1.8.9';

# Return file size expected by PNM header

sub file_size_from_header {
    my $filename = shift;
    my ( $magic_value, $width, $height, $bytes_per_channel, $header ) =
      read_header($filename);
    if ( not defined $magic_value ) { return 0 }
    if ( $magic_value == $BINARY_BITMAP ) {
        my $mod = $width % $BITS_PER_BYTE;
        if ( $mod > 0 ) { $width += $BITS_PER_BYTE - $mod }
    }
    my $datasize = $width * $height * $bytes_per_channel * (
        $magic_value == $BINARY_BITMAP ? $BITMAP_BYTES_PER_PIXEL
        : (
              $magic_value == $BINARY_GRAYMAP ? $GRAYMAP_CHANNELS
            : $PIXMAP_CHANNELS
        )
    );
    return $header + $datasize;
}

sub read_header {
    my $filename = shift;

    open my $fh, '<', $filename or return;
    my $header = <$fh>;
    my ( $magic_value, $width, $height, $line );
    my $bytes_per_channel = 1;
    if ( defined $header and $header =~ /^P(\d)\n/xsm ) {
        $magic_value = $1;
    }
    else {
        close $fh or return;
        return;
    }
    if ( $magic_value < $BINARY_BITMAP ) {
        close $fh or return;
        return;
    }
    while ( $line = <$fh> ) {
        $header .= $line;
        if ( $line =~ /^(\#|\s*\n)/xsm ) { next }
        if ( $line =~ /(\d*)[ ](\d*)\n/xsm ) {
            ( $width, $height ) = ( $1, $2 );
            if ( $magic_value == $BINARY_BITMAP ) { last }
        }
        elsif ( $magic_value > $BINARY_BITMAP and $line =~ /(\d+)\n/xsm ) {
            my $maxval = $1;
            $bytes_per_channel = log( $maxval + 1 ) / log(2) / $BITS_PER_BYTE;
            last;
        }
        else {
            close $fh or return;
            return;
        }
    }
    close $fh or return;
    return $magic_value, $width, $height, $bytes_per_channel, length $header;
}

1;

__END__
