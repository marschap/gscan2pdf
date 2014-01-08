package Gscan2pdf::Page;

use 5.008005;
use strict;
use warnings;
use Carp;
use Glib qw(TRUE FALSE);    # To get TRUE and FALSE
use File::Copy;
use File::Temp;             # To create temporary files
use HTML::TokeParser;
use HTML::Entities;
use Image::Magick;
use Encode;
use Locale::gettext 1.05;    # For translations
use POSIX qw(locale_h);
use Readonly;
Readonly my $CM_PER_INCH    => 2.54;
Readonly my $MM_PER_CM      => 10;
Readonly my $MM_PER_INCH    => $CM_PER_INCH * $MM_PER_CM;
Readonly my $PAGE_TOLERANCE => 0.02;

BEGIN {
 use Exporter ();
 our ( $VERSION, @EXPORT_OK, %EXPORT_TAGS );

 $VERSION = '1.2.0';

 use base qw(Exporter);
 %EXPORT_TAGS = ();    # eg: TAG => [ qw!name1 name2! ],

 # your exported package globals go here,
 # as well as any optionally exported functions
 @EXPORT_OK = qw();
}
our @EXPORT_OK;

my ( $d, $logger );

sub new {
 my ( $class, %options ) = @_;
 my $self = {};
 if ( not defined($d) ) {
  $d = Locale::gettext->domain(Glib::get_application_name);
 }

 if ( not defined( $options{filename} ) ) {
  croak "Error: filename not supplied";
 }
 if ( not -f $options{filename} )       { croak "Error: filename not found" }
 if ( not defined( $options{format} ) ) { croak "Error: format not supplied" }

 $logger->info("New page filename $options{filename}, format $options{format}");
 for ( keys %options ) {
  $self->{$_} = $options{$_};
 }

 # copy or move image to session directory
 my %suffix = (
  'Portable Network Graphics'                    => '.png',
  'Joint Photographic Experts Group JFIF format' => '.jpg',
  'Tagged Image File Format'                     => '.tif',
  'Portable anymap'                              => '.pnm',
  'Portable pixmap format (color)'               => '.ppm',
  'Portable graymap format (gray scale)'         => '.pgm',
  'Portable bitmap format (black and white)'     => '.pbm',
  'CompuServe graphics interchange format'       => '.gif',
 );
 $self->{filename} = File::Temp->new(
  DIR    => $options{dir},
  SUFFIX => $suffix{ $options{format} },
  UNLINK => FALSE,
 );
 if ( defined( $options{delete} ) and $options{delete} ) {
  move( $options{filename}, $self->{filename} )
    or croak
    sprintf( $d->get('Error importing image %s: %s'), $options{filename}, $! );
 }
 else {
  copy( $options{filename}, $self->{filename} )
    or croak
    sprintf( $d->get('Error importing image %s: %s'), $options{filename}, $! );
 }

 bless( $self, $class );
 return $self;
}

sub set_logger {
 ( my $class, $logger ) = @_;
 return;
}

sub clone {
 my ($self) = @_;
 my $new = {};
 for ( keys %{$self} ) {
  $new->{$_} = $self->{$_};
 }
 bless( $new, ref($self) );
 return $new;
}

# cloning File::Temp objects causes problems

sub freeze {
 my ($self) = @_;
 my $new = $self->clone;
 if ( ref( $new->{filename} ) eq 'File::Temp' ) {
  $new->{filename} = $self->{filename}->filename;
 }
 if ( ref( $new->{dir} ) eq 'File::Temp::Dir' ) {
  $new->{dir} = $self->{dir}->dirname;
 }
 return $new;
}

sub thaw {
 my ($self) = @_;
 my $new = $self->clone;
 my $suffix;
 if ( $new->{filename} =~ /\.(\w*)$/xsm ) {
  $suffix = $1;
 }
 my $filename = File::Temp->new( DIR => $new->{dir}, SUFFIX => ".$suffix" );
 move( $new->{filename}, $filename );
 $new->{filename} = $filename;
 return $new;
}

# returns array of boxes with OCR text

sub boxes {
 my ( $self, @boxes ) = @_;

 # Unfortunately, there seems to be a case (tested in t/31_ocropus_utf8.t)
 # where decode_entities doesn't work cleanly, so encode/decode to finally
 # get good UTF-8
 $self->{hocr} =
   decode_utf8(
  encode_utf8( HTML::Entities::decode_entities( $self->{hocr} ) ) );

 if ( $self->{hocr} =~ /<body>([\s\S]*)<\/body>/xsm ) {
  my $p = HTML::TokeParser->new( \$self->{hocr} );
  my ( $x1, $y1, $x2, $y2, $text );
  while ( my $token = $p->get_token ) {
   if ( $token->[0] eq 'S' ) {
    if (
         $token->[1] eq 'span'
     and defined( $token->[2]{class} )
     and ( $token->[2]{class} eq 'ocr_line'
      or $token->[2]{class} eq 'ocr_word'
      or $token->[2]{class} eq 'ocrx_word' )
     and defined( $token->[2]{title} )
     and $token->[2]{title} =~ /bbox\ (\d+)\ (\d+)\ (\d+)\ (\d+)/xsm
      )
    {
     ( $x1, $y1, $x2, $y2 ) = ( $1, $2, $3, $4 );
    }
    elsif ( $token->[1] eq 'span'
     and defined( $token->[2]{class} )
     and $token->[2]{class} eq 'ocr_cinfo' )
    {
     undef $x1;
     undef $text;
    }
   }
   if ( $token->[0] eq 'T' and $token->[1] !~ /^\s*$/xsm ) {
    $text = $token->[1];
    chomp($text);
   }
   if ( $token->[0] eq 'E' ) {
    undef $x1;
    undef $text;
   }
   if ( defined($x1) and defined($text) ) {
    push @boxes, [ $x1, $y1, $x2, $y2, $text ];
   }
  }
 }
 else {
  push @boxes, [ 0, 0, $self->{w}, $self->{h}, decode_utf8( $self->{hocr} ) ];
 }
 return @boxes;
}

sub to_png {
 my ( $self, $page_sizes ) = @_;

 # Write the png
 my $png =
   File::Temp->new( DIR => $self->{dir}, SUFFIX => '.png', UNLINK => FALSE );
 $self->im_object->Write(
  units    => 'PixelsPerInch',
  density  => $self->resolution($page_sizes),
  filename => $png
 );
 my $new = Gscan2pdf::Page->new(
  filename   => $png,
  format     => 'Portable Network Graphics',
  dir        => $self->{dir},
  resolution => $self->resolution($page_sizes),
 );
 return $new;
}

sub resolution {
 my ( $self, $paper_sizes ) = @_;
 return $self->{resolution} if defined( $self->{resolution} );
 my $image  = $self->im_object;
 my $format = $image->Get('format');
 setlocale( LC_NUMERIC, "C" );

 # Imagemagick always reports PNMs as 72ppi
 # Some versions of imagemagick report colour PNM as Portable pixmap (PPM)
 # B&W are Portable anymap
 if ( $format !~ /^Portable\ ...map/xsm ) {
  $self->{resolution} = $image->Get('x-resolution');

  if ( not defined( $self->{resolution} ) ) {
   $self->{resolution} = $image->Get('y-resolution');
  }

  if ( $self->{resolution} ) {
   if ( not $image->Get('units') eq 'PixelsPerInch' ) {
    $self->{resolution} *= $CM_PER_INCH;
   }
   return $self->{resolution};
  }
 }

 # Return the first match based on the format
 for ( values %{ $self->matching_paper_sizes($paper_sizes) } ) {
  $self->{resolution} = $_;
  return $self->{resolution};
 }

 # Default to 72
 $self->{resolution} = $Gscan2pdf::Document::POINTS_PER_INCH;
 return $self->{resolution};
}

# Given paper width and height (mm), and hash of paper sizes,
# returns hash of matching resolutions (pixels per inch)

sub matching_paper_sizes {
 my ( $self, $paper_sizes ) = @_;
 if ( not( defined( $self->{height} ) and defined( $self->{width} ) ) ) {
  my $image = $self->im_object;
  $self->{width}  = $image->Get('width');
  $self->{height} = $image->Get('height');
 }
 my $ratio = $self->{height} / $self->{width};
 if ( $ratio < 1 ) { $ratio = 1 / $ratio }
 my %matching;
 for ( keys %$paper_sizes ) {
  if ( $paper_sizes->{$_}{x} > 0
   and abs( $ratio - $paper_sizes->{$_}{y} / $paper_sizes->{$_}{x} ) <
   $PAGE_TOLERANCE )
  {
   $matching{$_} =
     ( ( $self->{height} > $self->{width} ) ? $self->{height} : $self->{width} )
     / $paper_sizes->{$_}{y} * $MM_PER_INCH;
  }
 }
 return \%matching;
}

# returns Image::Magick object

sub im_object {
 my ($self) = @_;
 my $image  = Image::Magick->new;
 my $x      = $image->Read( $self->{filename} );
 if ("$x") { $logger->warn($x) }
 return $image;
}

1;

__END__
