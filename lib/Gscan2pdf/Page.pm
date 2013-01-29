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

BEGIN {
 use Exporter ();
 our ( $VERSION, @EXPORT_OK, %EXPORT_TAGS );

 use base qw(Exporter);
 %EXPORT_TAGS = ();          # eg: TAG => [ qw!name1 name2! ],

 # your exported package globals go here,
 # as well as any optionally exported functions
 @EXPORT_OK = qw();
}
our @EXPORT_OK;

my ( $d, $logger );

sub new {
 my ( $class, %options ) = @_;
 my $self = {};
 $d = Locale::gettext->domain(Glib::get_application_name) unless ( defined $d );

 croak "Error: filename not supplied" unless ( defined $options{filename} );
 croak "Error: format not supplied"   unless ( defined $options{format} );

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
 $new->{filename} = $self->{filename}->filename
   if ( ref( $new->{filename} ) eq 'File::Temp' );
 $new->{dir} = $self->{dir}->dirname
   if ( ref( $new->{dir} ) eq 'File::Temp::Dir' );
 return $new;
}

sub thaw {
 my ($self) = @_;
 my $new = $self->clone;
 my $suffix;
 if ( $new->{filename} =~ /\.(\w*)$/x ) {
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

 if ( $self->{hocr} =~ /<body>([\s\S]*)<\/body>/x ) {
  my $p = HTML::TokeParser->new( \$self->{hocr} );
  my ( $x1, $y1, $x2, $y2, $text );
  while ( my $token = $p->get_token ) {
   if ( $token->[0] eq 'S' ) {
    if ( $token->[1] eq 'span'
     and defined( $token->[2]{class} )
     and
     ( $token->[2]{class} eq 'ocr_line' or $token->[2]{class} eq 'ocr_word' )
     and defined( $token->[2]{title} )
     and $token->[2]{title} =~ /bbox\ (\d+)\ (\d+)\ (\d+)\ (\d+)/x )
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
   if ( $token->[0] eq 'T' and $token->[1] !~ /^\s*$/x ) {
    $text = $token->[1];
    chomp($text);
   }
   if ( $token->[0] eq 'E' ) {
    undef $x1;
    undef $text;
   }
   push @boxes, [ $x1, $y1, $x2, $y2, $text ]
     if ( defined($x1) and defined($text) );
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
 if ( $format ne 'Portable anymap' ) {
  $self->{resolution} = $image->Get('x-resolution');

  $self->{resolution} = $image->Get('y-resolution')
    unless ( defined $self->{resolution} );

  if ( $self->{resolution} ) {
   $self->{resolution} *= 2.54
     unless ( $image->Get('units') eq 'PixelsPerInch' );
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
 unless ( defined( $self->{height} ) and defined( $self->{width} ) ) {
  my $image = $self->im_object;
  $self->{width}  = $image->Get('width');
  $self->{height} = $image->Get('height');
 }
 my $ratio = $self->{height} / $self->{width};
 $ratio = 1 / $ratio if ( $ratio < 1 );
 my %matching;
 for ( keys %$paper_sizes ) {
  if ( $paper_sizes->{$_}{x} > 0
   and abs( $ratio - $paper_sizes->{$_}{y} / $paper_sizes->{$_}{x} ) < 0.02 )
  {
   $matching{$_} =
     ( ( $self->{height} > $self->{width} ) ? $self->{height} : $self->{width} )
     / $paper_sizes->{$_}{y} * 25.4;
  }
 }
 return \%matching;
}

# returns Image::Magick object

sub im_object {
 my ($self) = @_;
 my $image  = Image::Magick->new;
 my $x      = $image->Read( $self->{filename} );
 $logger->warn($x) if "$x";
 return $image;
}

1;

__END__
