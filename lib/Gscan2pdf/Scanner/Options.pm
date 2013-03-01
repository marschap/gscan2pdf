package Gscan2pdf::Scanner::Options;

use strict;
use warnings;
use Carp;
use Glib qw(TRUE FALSE);    # To get TRUE and FALSE
use Sane 0.05;              # For enums
use feature "switch";

use Glib::Object::Subclass Glib::Object::;

my $units = qr/(pel|bit|mm|dpi|%|us)/x;

sub new_from_data {
 my ( $class, $options ) = @_;
 my $self = $class->new();
 croak "Error: no options supplied" unless ( defined $options );
 if ( ref($options) eq 'ARRAY' ) {

  # do a two level clone to allow us to add extra keys to the option hashes
  my @options;
  $self->{array} = \@options;
  for my $i ( 0 .. $#{$options} ) {
   my %option;
   %option = %{ $options->[$i] } if ( defined $options->[$i] );
   $option{index} = $i;
   push @options, \%option;
   $self->{hash}{ $options[$i]{name} } = $options[$i]
     if ( defined( $options[$i]{name} ) and $options[$i]{name} ne '' );
  }
 }
 else {
  ( $self->{array}, $self->{hash} ) = options2hash($options);
 }
 $self->parse_geometry;
 return $self;
}

sub by_index {
 my ( $self, $i ) = @_;
 return $self->{array}[$i];
}

sub by_name {
 my ( $self, $name ) = @_;
 return defined($name) ? $self->{hash}{$name} : undef;
}

sub num_options {
 my ($self) = @_;
 return $#{ $self->{array} } + 1;
}

sub delete_by_index {
 my ( $self, $i ) = @_;
 delete $self->{hash}{ $self->{array}[$i]{name} }
   if ( defined $self->{array}[$i]{name} );
 undef $self->{array}[$i];
 return;
}

sub delete_by_name {
 my ( $self, $name ) = @_;
 undef $self->{array}[ $self->{hash}{$name}{index} ];
 delete $self->{hash}{$name};
 return;
}

# Parse out the geometry from libsane-perl or scanimage option names

sub parse_geometry {
 my ($self) = @_;

 for ( ( SANE_NAME_PAGE_HEIGHT, 'pageheight' ) ) {
  if ( defined $self->{hash}{$_} ) {
   $self->{geometry}{h} = $self->{hash}{$_}{constraint}{max};
   last;
  }
 }
 for ( ( SANE_NAME_PAGE_WIDTH, 'pagewidth' ) ) {
  if ( defined $self->{hash}{$_} ) {
   $self->{geometry}{w} = $self->{hash}{$_}{constraint}{max};
   last;
  }
 }
 if ( defined $self->{hash}{ scalar(SANE_NAME_SCAN_TL_X) } ) {
  $self->{geometry}{l} =
    $self->{hash}{ scalar(SANE_NAME_SCAN_TL_X) }{constraint}{min};
  $self->{geometry}{x} =
    $self->{hash}{ scalar(SANE_NAME_SCAN_BR_X) }{constraint}{max} -
    $self->{geometry}{l}
    if ( defined $self->{hash}{ scalar(SANE_NAME_SCAN_BR_X) } );
 }
 elsif ( defined $self->{hash}{l} ) {
  $self->{geometry}{l} = $self->{hash}{l}{constraint}{min};
  $self->{geometry}{x} = $self->{hash}{x}{constraint}{max}
    if ( defined $self->{hash}{x}{constraint}{max} );
 }
 if ( defined $self->{hash}{ scalar(SANE_NAME_SCAN_TL_Y) } ) {
  $self->{geometry}{t} =
    $self->{hash}{ scalar(SANE_NAME_SCAN_TL_Y) }{constraint}{min};
  $self->{geometry}{y} =
    $self->{hash}{ scalar(SANE_NAME_SCAN_BR_Y) }{constraint}{max} -
    $self->{geometry}{t}
    if ( defined $self->{hash}{ scalar(SANE_NAME_SCAN_BR_Y) } );
 }
 elsif ( defined $self->{hash}{t} ) {
  $self->{geometry}{t} = $self->{hash}{t}{constraint}{min};
  $self->{geometry}{y} = $self->{hash}{y}{constraint}{max}
    if ( defined $self->{hash}{y}{constraint}{max} );
 }
 return;
}

sub supports_paper {
 my ( $self, $paper, $tolerance ) = @_;

 # Check the geometry against the paper size
 unless (   ## no critic (ProhibitNegativeExpressionsInUnlessAndUntilConditions)
      defined( $self->{geometry}{l} )
  and defined( $self->{geometry}{x} )
  and defined( $self->{geometry}{t} )
  and defined( $self->{geometry}{y} )
  and $self->{geometry}{l} <= $paper->{l} + $tolerance
  and $self->{geometry}{t} <= $paper->{t} + $tolerance
   )
 {
  return 0;
 }
 if ( defined( $self->{geometry}{h} ) and defined( $self->{geometry}{w} ) ) {
  if ( $self->{geometry}{h} + $tolerance >= $paper->{y} + $paper->{t}
   and $self->{geometry}{w} + $tolerance >= $paper->{x} + $paper->{l} )
  {
   return 1;
  }
  else {
   return 0;
  }
 }
 elsif ( $self->{geometry}{x} + $self->{geometry}{l} + $tolerance >=
      $paper->{x} + $paper->{l}
  and $self->{geometry}{y} + $self->{geometry}{t} + $tolerance >=
  $paper->{y} + $paper->{t} )
 {
  return 1;
 }
 return 0;
}

# parse the scanimage/scanadf output into an array and a hash

sub options2hash {
 my ($output) = @_;

 # Remove everything above the options
 if (
  $output =~ /
                       [\S\s]* # output header
                       Options\ specific\ to\ device .*:\n # line above options
                       ([\S\s]*) # options
                /x
   )
 {
  $output = $1;
 }
 else {
  return;
 }

 my ( @options, %hash );

 while (1) {
  my %option;
  $option{unit}            = SANE_UNIT_NONE;
  $option{constraint_type} = SANE_CONSTRAINT_NONE;
  my $values = qr/(?:(?:\ |\[=\()([^\[].*?)(?:\)\])?)?/x;

  # parse group
  if (
   $output =~ /
                      ^\ \ # two-character indent
                      (.*) # the title
                      :\n  # a colon at the end of the line
                      ([\S\s]*) # the rest of the output
                    /x
    )
  {
   $option{title}      = $1;
   $option{type}       = SANE_TYPE_GROUP;
   $option{cap}        = 0;
   $option{max_values} = 0;
   $option{name}       = '';
   $option{desc}       = '';

   # Remove everything on the option line and above.
   $output = $2;
  }

  # parse option
  elsif (
   $output =~ /
                      ^\ {4,} # four-character indent
                      -+        # at least one dash
                      ([\w\-]+) # the option name
                      $values      # optionally followed by the possible values
                      (?:\ \[([\S\s]*?)\])?  # optionally a space, followed by the current value in square brackets
                      \ *\n     # the rest of the line
                      ([\S\s]*) # the rest of the output
                    /x
    )
  {

   # scanimage & scanadf only display options if SANE_CAP_SOFT_DETECT is set
   $option{cap} = SANE_CAP_SOFT_DETECT + SANE_CAP_SOFT_SELECT;

   $option{name} = $1;
   if ( defined $3 ) {
    if ( $3 eq 'inactive' ) {
     $option{cap} += SANE_CAP_INACTIVE;
    }
    else {
     $option{val} = $3;
    }
    $option{max_values} = 1;
   }
   else {
    $option{type}       = SANE_TYPE_BUTTON;
    $option{max_values} = 0;
   }

   # parse the constraint after the current value
   # in order to be able to reset boolean values
   parse_constraint( \%option, $2 );

   # Remove everything on the option line and above.
   $output = $4;

   $hash{ $option{name} } = \%option;

   $option{title} = $option{name};
   $option{title} =~ s/[-_]/ /gx;     # dashes and underscores to spaces
   $option{title} =~
     s/\b(adf|cct|jpeg)\b/\U$1/gx;    # upper case comment abbreviations
   $option{title} =~ s/(^\w)/\U$1/xg; # capitalise at the beginning of the line
   given ( $option{title} ) {
    when ('L') {
     $option{title} = 'Top-left x';
    }
    when ('T') {
     $option{title} = 'Top-left y';
    }
    when ('X') {
     $option{title} = 'Width';
    }
    when ('Y') {
     $option{title} = 'Height';
    }
   }

   # Parse option description based on an 8-character indent.
   my $desc = '';
   while (
    $output =~ /
                       ^\ {8,}   # 8-character indent
                       (.*)\n    # text
                       ([\S\s]*) # rest of output
                     /x
     )
   {
    if ( $desc eq '' ) {
     $desc = $1;
    }
    else {
     $desc = "$desc $1";
    }

    # Remove everything on the description line and above.
    $output = $2;
   }

   $option{desc} = $desc;
  }
  else {
   last;
  }
  push @options, \%option;
  $option{index} = $#options + 1;
 }
 unshift @options, { index => 0 } if (@options);
 return \@options, \%hash;
}

# parse out range, step and units from the values string

sub parse_constraint {
 my ( $option, $values ) = @_;
 $option->{type} = SANE_TYPE_INT;
 $option->{type} = SANE_TYPE_FIXED
   if ( defined( $option->{val} ) and $option->{val} =~ /\./x );
 if (
  defined($values)
  and $values =~ /
                    (-?\d+\.?\d*)          # min value, possibly negative or floating
                    \.\.                   # two dots
                    (\d+\.?\d*)            # max value, possible floating
                    $units? # optional unit
                    (,\.\.\.)? # multiple values
                  /x
   )
 {
  $option->{constraint}{min} = $1;
  $option->{constraint}{max} = $2;
  $option->{constraint_type} = SANE_CONSTRAINT_RANGE;
  $option->{unit}       = unit2enum($3) if ( defined $3 );
  $option->{max_values} = 255           if ( defined $4 );
  $option->{constraint}{quant} = $1
    if (
   $values =~ /
                       \(              # opening round bracket
                       in\ steps\ of\  # text
                       (\d+\.?\d*)     # step
                       \)              # closing round bracket
                     /x
    );
  $option->{type} = SANE_TYPE_FIXED
    if (
      $option->{constraint}{min} =~ /\./x
   or $option->{constraint}{max} =~ /\./x
   or ( defined( $option->{constraint}{quant} )
    and $option->{constraint}{quant} =~ /\./x )
    );
 }
 elsif ( defined($values) and $values =~ /^<(\w+)>(,\.\.\.)?$/x ) {
  if ( $1 eq 'float' ) {
   $option->{type} = SANE_TYPE_FIXED;
  }
  elsif ( $1 eq 'string' ) {
   $option->{type} = SANE_TYPE_STRING;
  }
  $option->{max_values} = 255 if ( defined $2 );
 }

 # if we haven't got a boolean, and there is no constraint, we have a button
 elsif ( not defined($values) ) {
  $option->{type}       = SANE_TYPE_BUTTON;
  $option->{max_values} = 0;
 }
 else {
  parse_list_constraint( $option, $values );
 }
 return;
}

sub parse_list_constraint {
 my ( $option, $values ) = @_;
 if ( $values =~ /,\.\.\./x ) {
  $option->{max_values} = 255;
  $values = substr( $values, 0, length($values) - 4 );
 }
 my @array;
 while ( defined $values ) {
  my $i = index( $values, '|' );
  my $value;
  if ( $i > -1 ) {
   $value  = substr( $values, 0,      $i );
   $values = substr( $values, $i + 1, length($values) );
  }
  else {
   if ( $values =~ /$units$/x ) {
    my $unit = $1;
    $option->{unit} = unit2enum($unit);
    $values = substr( $values, 0, index( $values, $unit ) );
   }
   $value = $values;
   undef $values;
  }
  push @array, $value if ( $value ne '' );
 }
 if (@array) {
  if ( $array[0] eq 'auto' ) {
   $option->{cap} += SANE_CAP_AUTOMATIC;
   shift @array;
  }
  if ( @array == 2 and $array[0] eq 'yes' and $array[1] eq 'no' ) {
   $option->{type} = SANE_TYPE_BOOL;
   if ( defined $option->{val} ) {
    if ( $option->{val} eq 'yes' ) {
     $option->{val} = SANE_TRUE;
    }
    else {
     $option->{val} = SANE_FALSE;
    }
   }
  }
  else {

   # Can't check before because 'auto' would mess things up
   for (@array) {
    if (/[[:alpha:]]/x) {
     $option->{type} = SANE_TYPE_STRING;
    }
    elsif (/\./x) {
     $option->{type} = SANE_TYPE_FIXED;
    }
   }
   $option->{constraint} = [@array];
   $option->{constraint_type} =
     $option->{type} == SANE_TYPE_STRING
     ? SANE_CONSTRAINT_STRING_LIST
     : SANE_CONSTRAINT_WORD_LIST;
  }
 }
 return;
}

sub unit2enum {
 my ($unit) = @_;
 given ($unit) {
  when ('pel') {
   return SANE_UNIT_PIXEL;
  }
  when ('bit') {
   return SANE_UNIT_BIT;
  }
  when ('mm') {
   return SANE_UNIT_MM;
  }
  when ('dpi') {
   return SANE_UNIT_DPI;
  }
  when ('%') {
   return SANE_UNIT_PERCENT;
  }
  when ('us') {
   return SANE_UNIT_MICROSECOND;
  }
 }
 return;
}

1;

__END__
