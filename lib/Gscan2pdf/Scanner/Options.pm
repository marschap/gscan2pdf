package Gscan2pdf::Scanner::Options;

use strict;
use warnings;
no if $] >= 5.018, warnings => 'experimental::smartmatch';
use Carp;
use Glib qw(TRUE FALSE);    # To get TRUE and FALSE
use Image::Sane ':all';     # For enums
use Storable qw(dclone);    # For cloning the options cache
use feature 'switch';
use Readonly;
Readonly my $MAX_VALUES  => 255;
Readonly my $EMPTY_ARRAY => -1;

# Have to subclass Glib::Object to be able to name it as an object in
# Glib::ParamSpec->object in Gscan2pdf::Dialog::Scan
use Glib::Object::Subclass Glib::Object::;

our $VERSION = '1.8.10';

my $units = qr{(pel|bit|mm|dpi|%|us)}xsm;
my $EMPTY = q{};
my $list  = ',...';
my $device;

sub new_from_data {
    my ( $class, $options ) = @_;
    my $self = $class->new();
    if ( not defined $options ) { croak 'Error: no options supplied' }
    if ( ref($options) eq 'ARRAY' ) {
        $self->{array} = $options;
    }
    else {
        $self->{array} = _parse_scanimage_output($options);
    }

    # add hash for easy retrieval
    for my $i ( 0 .. $#{ $self->{array} } ) {
        my $option;
        if ( defined $self->{array}[$i] ) { $option = $self->{array}[$i] }
        $option->{index} = $i;
        if ( not defined $self->{array}[$i] ) { $self->{array}[$i] = $option }
        if ( defined $self->{array}[$i]{name}
            and $self->{array}[$i]{name} ne $EMPTY )
        {
            $self->{hash}{ $self->{array}[$i]{name} } = $self->{array}[$i];
        }
    }

    # find source option
    if ( defined $self->by_name('source') ) {
        $self->{source} = $self->by_name('source');
    }
    else {
        for my $option ( @{ $self->{array} } ) {
            if ( defined $option->{name} and $option->{name} =~ /source/xsm ) {
                $self->{source} = $option;
                last;
            }
        }
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
    return ( defined $name and defined $self->{hash}{$name} )
      ? $self->{hash}{$name}
      : undef;
}

sub by_title {
    my ( $self, $title ) = @_;
    for ( @{ $self->{array} } ) {
        return $_ if ( defined( $_->{title} ) and $_->{title} eq $title );
    }
    return;
}

sub num_options {
    my ($self) = @_;
    return $#{ $self->{array} } + 1;
}

sub delete_by_index {
    my ( $self, $i ) = @_;
    if ( defined $self->{array}[$i]{name} ) {
        delete $self->{hash}{ $self->{array}[$i]{name} };
    }
    undef $self->{array}[$i];
    return;
}

sub delete_by_name {
    my ( $self, $name ) = @_;
    undef $self->{array}[ $self->{hash}{$name}{index} ];
    delete $self->{hash}{$name};
    return;
}

sub device {
    return $device;
}

# Parse out the geometry from libimage-sane-perl or scanimage option names

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
    if ( defined $self->{hash}{ scalar SANE_NAME_SCAN_TL_X } ) {
        $self->{geometry}{l} =
          $self->{hash}{ scalar SANE_NAME_SCAN_TL_X }{constraint}{min};
        if ( defined $self->{hash}{ scalar SANE_NAME_SCAN_BR_X } ) {
            $self->{geometry}{x} =
              $self->{hash}{ scalar SANE_NAME_SCAN_BR_X }{constraint}{max} -
              $self->{geometry}{l};
        }
    }
    elsif ( defined $self->{hash}{l} ) {
        $self->{geometry}{l} = $self->{hash}{l}{constraint}{min};
        if ( defined $self->{hash}{x}{constraint}{max} ) {
            $self->{geometry}{x} = $self->{hash}{x}{constraint}{max};
        }
    }
    if ( defined $self->{hash}{ scalar SANE_NAME_SCAN_TL_Y } ) {
        $self->{geometry}{t} =
          $self->{hash}{ scalar SANE_NAME_SCAN_TL_Y }{constraint}{min};
        if ( defined $self->{hash}{ scalar SANE_NAME_SCAN_BR_Y } ) {
            $self->{geometry}{y} =
              $self->{hash}{ scalar SANE_NAME_SCAN_BR_Y }{constraint}{max} -
              $self->{geometry}{t};
        }
    }
    elsif ( defined $self->{hash}{t} ) {
        $self->{geometry}{t} = $self->{hash}{t}{constraint}{min};
        if ( defined $self->{hash}{y}{constraint}{max} ) {
            $self->{geometry}{y} = $self->{hash}{y}{constraint}{max};
        }
    }
    return;
}

sub supports_paper {
    my ( $self, $paper, $tolerance ) = @_;

    # Check the geometry against the paper size
    if (
        not(    defined( $self->{geometry}{l} )
            and defined( $self->{geometry}{x} )
            and defined( $self->{geometry}{t} )
            and defined( $self->{geometry}{y} )
            and $self->{geometry}{l} <= $paper->{l} + $tolerance
            and $self->{geometry}{t} <= $paper->{t} + $tolerance )
      )
    {
        return 0;
    }
    if ( defined( $self->{geometry}{h} ) and defined( $self->{geometry}{w} ) ) {
        if (    $self->{geometry}{h} + $tolerance >= $paper->{y} + $paper->{t}
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

# returns TRUE if the current options support duplex, even if not currently
# selected. Alternatively expressed, return FALSE if the scanner is not capable
# of duplex scanner, or if the capability is inactive.

sub can_duplex {
    my ($self) = @_;
    for my $option ( @{ $self->{array} } ) {
        if (
            not( defined $option->{cap}
                and ( $option->{cap} & SANE_CAP_INACTIVE ) )
          )
        {
            if ( defined $option->{name} and $option->{name} =~ /duplex/xsmi ) {
                return TRUE;
            }
            elsif ( defined $option->{constraint_type}
                and $option->{constraint_type} == SANE_CONSTRAINT_STRING_LIST )
            {
                for my $item ( @{ $option->{constraint} } ) {
                    if ( $item =~ /duplex/xsmi ) {
                        return TRUE;
                    }
                }
            }
        }
    }
    return FALSE;
}

# returns TRUE/FALSE if the value is within the tolerance of the given option or
# not, and undef for options with no value or for an invalid value

sub within_tolerance {
    my ( $option, $value ) = @_;
    given ( $option->{constraint_type} ) {
        when (SANE_CONSTRAINT_RANGE) {
            if ( defined $option->{constraint}{quant} ) {
                return (
                    abs( $value - $option->{val} ) <=
                      $option->{constraint}{quant} / 2 );
            }
        }
        when (SANE_CONSTRAINT_STRING_LIST) {
            return ( $value eq $option->{val} );
        }
        when (SANE_CONSTRAINT_WORD_LIST) {
            return ( $value == $option->{val} );
        }
    }
    given ( $option->{type} ) {
        when (SANE_TYPE_BOOL) {
            return not( $value xor $option->{val} );
        }
        when (SANE_TYPE_STRING) {
            return ( $value eq $option->{val} );
        }
        when ( $_ == SANE_TYPE_INT or $_ == SANE_TYPE_FIXED ) {
            return ( $value == $option->{val} );
        }
    }
    return;
}

# parse the scanimage/scanadf output into an array and a hash

sub _parse_scanimage_output {
    my ($output) = @_;

    # Remove everything above the options
    if (
        $output =~ qr{
                       Options[ ]specific[ ]to[ ]device[ ] # string
                       `(.+)':\n # device name
                       (.*) # options
                }xsm
      )
    {
        $device = $1;
        $output = $2;
    }
    else {
        return;
    }

    my @options;
    while (1) {
        my %option;
        $option{unit}            = SANE_UNIT_NONE;
        $option{constraint_type} = SANE_CONSTRAINT_NONE;
        my $values = qr{(?:(?:[ ]|[[]=[(])([^[].*?)(?:[)]\])?)?}xsm;

        # parse group
        if (
            $output =~ qr{
                      \A[ ]{2} # two-character indent
                      ([^\n]*) # the title
                      :\n  # a colon at the end of the line
                      (.*) # the rest of the output
                    }xsm
          )
        {
            $option{title}      = $1;
            $option{type}       = SANE_TYPE_GROUP;
            $option{cap}        = 0;
            $option{max_values} = 0;
            $option{name}       = $EMPTY;
            $option{desc}       = $EMPTY;

            # Remove everything on the option line and above.
            $output = $2;
        }

        # parse option
        elsif (
            $output =~ qr{
                      \A[ ]{4,} # four-character indent
                      -+        # at least one dash
                      ([\w\-]+) # the option name
                      $values      # optionally followed by the possible values
                      (?:[ ][[](.*?)[]])?  # optionally a space, followed by the current value in square brackets
                      [ ]*\n     # the rest of the line
                      (.*) # the rest of the output
                    }xsm
          )
        {

            # scanimage & scanadf only display options
            # if SANE_CAP_SOFT_DETECT is set
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

            $option{title} = $option{name};
            $option{title} =~ s/[-_]/ /xsmg;  # dashes and underscores to spaces
            $option{title} =~
              s/\b(adf|cct|jpeg)\b/\U$1/xsmg; # upper case comment abbreviations
            $option{title} =~
              s/(^\w)/\U$1/xsmg;    # capitalise at the beginning of the line

            # Parse option description based on an 8-character indent.
            my $desc = $EMPTY;
            while (
                $output =~ qr{
                       \A[ ]{8,}   # 8-character indent
                       ([^\n]*)\n    # text
                       (.*) # rest of output
                     }xsm
              )
            {
                if ( $desc eq $EMPTY ) {
                    $desc = $1;
                }
                else {
                    $desc = "$desc $1";
                }

                # Remove everything on the description line and above.
                $output = $2;
            }

            $option{desc} = $desc;

            given ( $option{name} ) {
                when ('l') {
                    $option{name}  = SANE_NAME_SCAN_TL_X;
                    $option{title} = 'Top-left x';
                }
                when ('t') {
                    $option{name}  = SANE_NAME_SCAN_TL_Y;
                    $option{title} = 'Top-left y';
                }
                when ('x') {
                    $option{name}  = SANE_NAME_SCAN_BR_X;
                    $option{title} = 'Bottom-right x';
                    $option{desc}  = 'Bottom-right x position of scan area.';
                }
                when ('y') {
                    $option{name}  = SANE_NAME_SCAN_BR_Y;
                    $option{title} = 'Bottom-right y';
                    $option{desc}  = 'Bottom-right y position of scan area.';
                }
            }
        }
        else {
            last;
        }
        push @options, \%option;
        $option{index} = $#options + 1;
    }
    if (@options) { unshift @options, { index => 0 } }
    return \@options;
}

# parse out range, step and units from the values string

sub parse_constraint {
    my ( $option, $values ) = @_;
    $option->{type} = SANE_TYPE_INT;
    if ( defined( $option->{val} ) and $option->{val} =~ /[.]/xsm ) {
        $option->{type} = SANE_TYPE_FIXED;
    }
    if (
        defined $values
        and $values =~ qr{
                    (-?\d+[.]?\d*)          # min value, possibly negative or floating
                    [.]{2}                   # two dots
                    (\d+[.]?\d*)            # max value, possible floating
                    $units? # optional unit
                    ($list)? # multiple values
                  }xsm
      )
    {
        $option->{constraint}{min} = $1;
        $option->{constraint}{max} = $2;
        $option->{constraint_type} = SANE_CONSTRAINT_RANGE;
        if ( defined $3 ) { $option->{unit}       = unit2enum($3) }
        if ( defined $4 ) { $option->{max_values} = $MAX_VALUES }
        if (
            $values =~ qr{
                       [(]              # opening round bracket
                       in[ ]steps[ ]of[ ] # text
                       (\d+[.]?\d*)     # step
                       [)]              # closing round bracket
                     }xsm
          )
        {
            $option->{constraint}{quant} = $1;
        }
        if (
               $option->{constraint}{min} =~ /[.]/xsm
            or $option->{constraint}{max} =~ /[.]/xsm
            or ( defined( $option->{constraint}{quant} )
                and $option->{constraint}{quant} =~ /[.]/xsm )
          )
        {
            $option->{type} = SANE_TYPE_FIXED;
        }
    }
    elsif ( defined $values and $values =~ /^<(\w+)>($list)?$/xsm ) {
        if ( $1 eq 'float' ) {
            $option->{type} = SANE_TYPE_FIXED;
        }
        elsif ( $1 eq 'string' ) {
            $option->{type} = SANE_TYPE_STRING;
        }
        if ( defined $2 ) { $option->{max_values} = $MAX_VALUES }
    }

    # if we haven't got a boolean, and there is no constraint, we have a button
    elsif ( not defined $values ) {
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
    if ( $values =~ /(.*)$list/xsm ) {
        $values = $1;
        $option->{max_values} = $MAX_VALUES;
    }
    if ( $values =~ /(.*)$units$/xsm ) {
        $values = $1;
        $option->{unit} = unit2enum($2);
    }
    my @array = split /[|]+/xsm, $values;
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
                if (/[[:alpha:]]/xsm) {
                    $option->{type} = SANE_TYPE_STRING;
                }
                elsif (/[.]/xsm) {
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
        when (q{%}) {
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
