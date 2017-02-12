package Gscan2pdf::Scanner::Profile;

use strict;
use warnings;
no if $] >= 5.018, warnings => 'experimental::smartmatch';
use feature 'switch';
use Carp;
use Glib qw(TRUE FALSE);    # To get TRUE and FALSE
use Sane 0.05;              # For enums
use Storable qw(dclone);
use Readonly;
Readonly my $EMPTY_ARRAY => -1;
Readonly my $REVERSE     => TRUE;

# Have to subclass Glib::Object to be able to name it as an object in
# Glib::ParamSpec->object in Gscan2pdf::Dialog::Scan
use Glib::Object::Subclass Glib::Object::;

our $VERSION = '1.7.2';

my $EMPTY = q{};

sub new_from_data {
    my ( $class, $hash ) = @_;
    my $self = $class->new();
    if ( not defined $hash ) { croak 'Error: no profile supplied' }
    $self->{data} = $hash;
    return $self->map_from_cli;
}

# the oldval option is a hack to allow us not to apply geometry options
# if setting paper as part of a profile

sub add_backend_option {
    my ( $self, $name, $val, $oldval ) = @_;
    if ( not defined $name or $name eq $EMPTY ) {
        croak 'Error: no option name';
    }
    if ( defined $oldval and $val == $oldval ) { return }
    push @{ $self->{data}{backend} }, { $name => $val };

    # Note any duplicate options, keeping only the last entry.
    my %seen;

    my $iter = $self->each_backend_option($REVERSE);
    while ( my $i = $iter->() ) {
        my ($opt) = $self->get_backend_option_by_index($i);
        my $synonyms = _synonyms($opt);
        for ( @{$synonyms} ) {
            $seen{$_}++;
            if ( defined $seen{$_} and $seen{$_} > 1 ) {
                $self->remove_backend_option_by_index($i);
                last;
            }
        }
    }
    return;
}

sub get_backend_option_by_index {
    my ( $self, $i ) = @_;
    return %{ $self->{data}{backend}[ $i - 1 ] };
}

sub remove_backend_option_by_index {
    my ( $self, $i ) = @_;
    splice @{ $self->{data}{backend} }, $i - 1, 1;
    return;
}

# an iterator for backend options
# index returned by iterator 1 greater than index to allow
# my $iter = $self->each_backend_option;
# while (my $i = $iter->()) {}
# otherwise the first iterator would return 0,
# which would then not enter the while loop

sub each_backend_option {
    my ( $self, $backwards ) = @_;

    my $iter;

    return sub {
        my ($step) = @_;

        if ( not defined $iter ) {
            $iter = ( $backwards ? $#{ $self->{data}{backend} } : 0 ) + 1;
        }
        elsif ( not defined $step or $step ) {
            $iter = $backwards ? $iter - 1 : $iter + 1;
        }
        if (   ( $backwards and $iter == 0 )
            or ( not $backwards and $iter == $#{ $self->{data}{backend} } + 2 )
          )
        {
            return;
        }
        return $iter;
    };
}

sub num_backend_options {
    my ($self) = @_;
    if ( not defined $self->{data}{backend} ) { return }
    return scalar @{ $self->{data}{backend} };
}

sub add_frontend_option {
    my ( $self, $name, $val ) = @_;
    if ( not defined $name or $name eq $EMPTY ) {
        croak 'Error: no option name';
    }
    $self->{data}{frontend}{$name} = $val;
    return;
}

# an iterator for frontend options
# option name returned by iterator
# my $iter = $self->each_backend_option;
# while (my $name = $iter->()) {}

sub each_frontend_option {
    my ($self) = @_;
    my @keys   = keys %{ $self->{data}{frontend} };
    my $next   = 0;
    return sub {
        if ( $next > $#keys ) { return }
        return $keys[ $next++ ];
    };
}

sub get_frontend_option {
    my ( $self, $name ) = @_;
    return $self->{data}{frontend}{$name};
}

sub get_data {
    my ($self) = @_;
    return $self->{data};
}

# Map scanimage and scanadf (CLI) geometry options to the backend geometry names

sub map_from_cli {
    my ($self) = @_;
    my $new    = Gscan2pdf::Scanner::Profile->new;
    my $iter   = $self->each_backend_option;
    while ( my $i = $iter->() ) {
        my ( $name, $val ) = $self->get_backend_option_by_index($i);
        given ($name) {
            when ('l') {
                $new->add_backend_option( SANE_NAME_SCAN_TL_X, $val );
            }
            when ('t') {
                $new->add_backend_option( SANE_NAME_SCAN_TL_Y, $val );
            }
            when ('x') {
                my $l = $self->get_option_by_name('l');
                if ( not defined $l ) {
                    $l = $self->get_option_by_name(SANE_NAME_SCAN_TL_X);
                }
                if ( defined $l ) { $val += $l }
                $new->add_backend_option( SANE_NAME_SCAN_BR_X, $val );
            }
            when ('y') {
                my $t = $self->get_option_by_name('t');
                if ( not defined $t ) {
                    $t = $self->get_option_by_name(SANE_NAME_SCAN_TL_Y);
                }
                if ( defined $t ) { $val += $t }
                $new->add_backend_option( SANE_NAME_SCAN_BR_Y, $val );
            }
            default {
                $new->add_backend_option( $name, $val );
            }
        }
    }
    if ( defined $self->{data}{frontend} ) {
        $new->{data}{frontend} = dclone( $self->{data}{frontend} );
    }
    return $new;
}

# Map backend geometry options to the scanimage and scanadf (CLI) geometry names

sub map_to_cli {
    my ( $self, $options ) = @_;
    my $new  = Gscan2pdf::Scanner::Profile->new;
    my $iter = $self->each_backend_option;
    while ( my $i = $iter->() ) {
        my ( $name, $val ) = $self->get_backend_option_by_index($i);
        given ($name) {
            when (SANE_NAME_SCAN_TL_X) {
                $new->add_backend_option( 'l', $val );
            }
            when (SANE_NAME_SCAN_TL_Y) {
                $new->add_backend_option( 't', $val );
            }
            when (SANE_NAME_SCAN_BR_X) {
                my $l = $self->get_option_by_name('l');
                if ( not defined $l ) {
                    $l = $self->get_option_by_name(SANE_NAME_SCAN_TL_X);
                }
                if ( defined $l ) { $val -= $l }
                $new->add_backend_option( 'x', $val );
            }
            when (SANE_NAME_SCAN_BR_Y) {
                my $t = $self->get_option_by_name('t');
                if ( not defined $t ) {
                    $t = $self->get_option_by_name(SANE_NAME_SCAN_TL_Y);
                }
                if ( defined $t ) { $val -= $t }
                $new->add_backend_option( 'y', $val );
            }
            default {
                if ( defined $options ) {
                    my $opt = $options->by_name($name);
                    if ( defined( $opt->{type} )
                        and $opt->{type} == SANE_TYPE_BOOL )
                    {
                        $val = $val ? 'yes' : 'no';
                    }
                }
                $new->add_backend_option( $name, $val );
            }
        }
    }
    if ( defined $self->{data}{frontend} ) {
        $new->{data}{frontend} = dclone( $self->{data}{frontend} );
    }
    return $new;
}

# Extract a option value from a profile

sub get_option_by_name {
    my ( $self, $name ) = @_;
    my $iter = $self->each_backend_option;
    while ( my $i = $iter->() ) {
        my ( $key, $val ) = $self->get_backend_option_by_index($i);
        if ( $key eq $name ) { return $val }
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
