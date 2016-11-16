package Gscan2pdf::Scanner::Profile;

use strict;
use warnings;
no if $] >= 5.018, warnings => 'experimental::smartmatch';
use feature 'switch';
use Carp;
use Glib qw(TRUE FALSE);    # To get TRUE and FALSE
use Sane 0.05;              # For enums
use Storable qw(dclone);
use Data::Dumper;
use Readonly;
Readonly my $EMPTY_ARRAY => -1;

# Have to subclass Glib::Object to be able to name it as an object in
# Glib::ParamSpec->object in Gscan2pdf::Dialog::Scan
use Glib::Object::Subclass Glib::Object::;

our $VERSION = '1.6.0';

my $EMPTY = q{};

sub new_from_data {
    my ( $class, $hash ) = @_;
    my $self = $class->new();
    if ( not defined $hash ) { croak 'Error: no profile supplied' }
    $self->{data} = dclone($hash);
    $self->map_from_cli;
    return $self;
}

sub add_backend_option {
    my ( $self, $name, $val ) = @_;
    if ( not defined $name or $name eq $EMPTY ) {
        croak 'Error: no option name';
    }
    push @{ $self->{data}{backend} }, { $name => $val };

    # Note any duplicate options, keeping only the last entry.
    my %seen;
    my $j = $#{ $self->{data}{backend} };
    while ( $j > $EMPTY_ARRAY ) {
        my ($opt) = keys %{ $self->{data}{backend}[$j] };
        my $synonyms = _synonyms($opt);
        for ( @{$synonyms} ) {
            $seen{$_}++;
            if ( defined $seen{$_} and $seen{$_} > 1 ) {
                splice @{ $self->{data}{backend} }, $j, 1;
                last;
            }
        }
        $j--;
    }

    return;
}

sub add_frontend_option {
    my ( $self, $name, $val ) = @_;
    if ( not defined $name or $name eq $EMPTY ) {
        croak 'Error: no option name';
    }
    $self->{data}{frontend}{$name} = $val;
    return;
}

sub get_data {
    my ($self) = @_;
    return $self->{data};
}

# Map scanimage and scanadf (CLI) geometry options to the backend geometry names

sub map_from_cli {
    my ($self) = @_;
    for my $i ( 0 .. $#{ $self->{data}{backend} } ) {

        # for reasons I don't understand, without walking the reference tree,
        # parts of $options are undef
        Dumper( $self->{data}{backend} );
        my ( $name, $val ) = each %{ $self->{data}{backend}[$i] };
        given ($name) {
            when ('l') {
                $name = SANE_NAME_SCAN_TL_X;
                $self->{data}{backend}[$i] = { $name => $val };
            }
            when ('t') {
                $name = SANE_NAME_SCAN_TL_Y;
                $self->{data}{backend}[$i] = { $name => $val };
            }
            when ('x') {
                $name = SANE_NAME_SCAN_BR_X;
                my $l = $self->get_option_by_name('l');
                if ( not defined $l ) {
                    $l = $self->get_option_by_name(SANE_NAME_SCAN_TL_X);
                }
                if ( defined $l ) { $val += $l }
                $self->{data}{backend}[$i] = { $name => $val };
            }
            when ('y') {
                $name = SANE_NAME_SCAN_BR_Y;
                my $t = $self->get_option_by_name('t');
                if ( not defined $t ) {
                    $t = $self->get_option_by_name(SANE_NAME_SCAN_TL_Y);
                }
                if ( defined $t ) { $val += $t }
                $self->{data}{backend}[$i] = { $name => $val };
            }
        }
    }
    return;
}

# Map backend geometry options to the scanimage and scanadf (CLI) geometry names

sub map_to_cli {
    my ($self) = @_;
    for my $i ( 0 .. $#{ $self->{data}{backend} } ) {

        # for reasons I don't understand, without walking the reference tree,
        # parts of $options are undef
        Dumper( $self->{data}{backend}[$i] );

        my ( $name, $val ) = each %{ $self->{data}{backend}[$i] };
        given ($name) {
            when (SANE_NAME_SCAN_TL_X) {
                $self->{data}{backend}[$i] = { l => $val };
            }
            when (SANE_NAME_SCAN_TL_Y) {
                $self->{data}{backend}[$i] = { t => $val };
            }
            when (SANE_NAME_SCAN_BR_X) {
                my $l = $self->get_option_by_name('l');
                if ( not defined $l ) {
                    $l = $self->get_option_by_name(SANE_NAME_SCAN_TL_X);
                }
                if ( defined $l ) { $val -= $l }
                $self->{data}{backend}[$i] = { x => $val };
            }
            when (SANE_NAME_SCAN_BR_Y) {
                my $t = $self->get_option_by_name('t');
                if ( not defined $t ) {
                    $t = $self->get_option_by_name(SANE_NAME_SCAN_TL_Y);
                }
                if ( defined $t ) { $val -= $t }
                $self->{data}{backend}[$i] = { y => $val };
            }
        }
    }
    return;
}

# Extract a option value from a profile

sub get_option_by_name {
    my ( $self, $name ) = @_;

    # for reasons I don't understand, without walking the reference tree,
    # parts of $profile are undef
    Dumper($self);
    for ( @{ $self->{data}{backend} } ) {
        my ( $key, $val ) = each %{$_};
        return $val if ( $key eq $name );
    }
    return;
}

sub _synonyms {
    my ($name) = @_;
    my @synonyms = (
        [ scalar(SANE_NAME_PAGE_HEIGHT), 'pageheight' ],
        [ scalar(SANE_NAME_PAGE_WIDTH),  'pagewidth' ],
        [ scalar(SANE_NAME_SCAN_TL_X),   'l' ],
        [ scalar(SANE_NAME_SCAN_TL_Y),   't' ],
        [ scalar(SANE_NAME_SCAN_BR_X),   'x' ],
        [ scalar(SANE_NAME_SCAN_BR_Y),   'y' ],
    );
    for my $synonym (@synonyms) {
        given ($name) {
            when ( @{$synonym} ) {
                return $synonym;
            }
        }
    }
    return [$name];
}

1;

__END__
