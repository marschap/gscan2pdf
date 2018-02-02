package Gscan2pdf::ImageView;

use warnings;
use strict;
no if $] >= 5.018, warnings => 'experimental::smartmatch';
use feature 'switch';
use Cairo;
use Glib qw(TRUE FALSE);    # To get TRUE and FALSE
use Gtk3;
use List::Util qw(min);
use Carp;

our $VERSION = '1.8.11';

use Glib::Object::Subclass Gtk3::DrawingArea::, signals => {
    'zoom-changed' => {
        param_types => ['Glib::Float'],    # new zoom
    },
  },
  properties => [
    Glib::ParamSpec->scalar(
        'pixbuf',                             # name
        'pixbuf',                             # nickname
        'Cairo::ImageSurface to be shown',    # blurb
        [qw/readable writable/]               # flags
    ),
    Glib::ParamSpec->scalar(
        'offset',                                               # name
        'Image offset',                                         # nick
        'Gdk::Rectangle hash of image x, y, width, height.',    # blurb
        [qw/readable writable/]                                 # flags
    ),
    Glib::ParamSpec->float(
        'zoom',                                                 # name
        'zoom',                                                 # nick
        'zoom level',                                           # blurb
        0.001,                                                  # minimum
        1000.0,                                                 # maximum
        1.0,                                                    # default_value
        [qw/readable writable/]                                 # flags
    ),
  ];

sub INIT_INSTANCE {
    my $self = shift;
    $self->signal_connect( draw                   => \&_draw );
    $self->signal_connect( 'button-press-event'   => \&_button_pressed );
    $self->signal_connect( 'button-release-event' => \&_button_released );
    $self->signal_connect( 'motion-notify-event'  => \&_motion );
    $self->signal_connect( 'scroll-event'         => \&_scroll );
    $self->set_app_paintable(TRUE);
    $self->add_events(
        Glib::Object::Introspection->convert_sv_to_flags(
            'Gtk3::Gdk::EventMask', 'exposure-mask' ) |
          Glib::Object::Introspection->convert_sv_to_flags(
            'Gtk3::Gdk::EventMask', 'button-press-mask' ) |
          Glib::Object::Introspection->convert_sv_to_flags(
            'Gtk3::Gdk::EventMask', 'button-release-mask' ) |
          Glib::Object::Introspection->convert_sv_to_flags(
            'Gtk3::Gdk::EventMask', 'pointer-motion-mask' ) |
          Glib::Object::Introspection->convert_sv_to_flags(
            'Gtk3::Gdk::EventMask', 'scroll-mask'
          )
    );

    #   $self->signal_connect( 'zoom-changed' => sub { $self->_update_image } );
    return $self;
}

sub SET_PROPERTY {
    my ( $self, $pspec, $newval ) = @_;
    my $name   = $pspec->get_name;
    my $oldval = $self->get($name);
    if (   ( defined $newval and defined $oldval and $newval ne $oldval )
        or ( defined $newval xor defined $oldval ) )
    {
        given ($name) {
            when ('pixbuf') {
                $self->{$name} = $newval;
            }
            when ('zoom') {
                $self->{$name} = $newval;
                $self->signal_emit( 'zoom-changed', $newval );
            }
            default {
                $self->{$name} = $newval;

                #                $self->SUPER::SET_PROPERTY( $pspec, $newval );
            }
        }
    }
    return;
}

sub set_pixbuf {
    my ( $self, $pixbuf, $zoom_to_fit ) = @_;
    if ( defined $pixbuf and not $pixbuf->isa('Cairo::ImageSurface') ) {
        croak 'Error type ', ref($pixbuf), ' is not a Cairo::ImageSurface';
    }
    $self->set( 'pixbuf', $pixbuf );
    if ( defined $pixbuf ) {
        my $offset = $self->get('offset');
        $offset->{width}  = $pixbuf->get_width;
        $offset->{height} = $pixbuf->get_height;
        if ( not defined $offset->{x} ) { $offset->{x} = 0 }
        if ( not defined $offset->{y} ) { $offset->{y} = 0 }
        $self->set( 'offset', $offset );
    }
    if ($zoom_to_fit) {
        $self->zoom_to_fit;
    }
    else {
        my $win = $self->get_window();
        $win->invalidate_rect( $self->get_allocation, FALSE );
    }
    return;
}

sub get_pixbuf {
    my ($self) = @_;
    return $self->get('pixbuf');
}

sub _button_pressed {
    my ( $self, $event ) = @_;

    # left mouse button
    if ( $event->button != 1 ) { return FALSE }

    $self->{pan_start} = { x => $event->x, y => $event->y };
    $self->{panning} = TRUE;
    return TRUE;
}

sub _button_released {
    my ( $self, $event ) = @_;
    $self->{panning} = FALSE;
    return;
}

sub _motion {
    my ( $self, $event ) = @_;
    if ( not $self->{panning} ) { return FALSE }

    my $offset = $self->get('offset');
    $offset->{x} += $event->x - $self->{pan_start}{x};
    $offset->{y} += $event->y - $self->{pan_start}{y};
    ( $self->{pan_start}{x}, $self->{pan_start}{y} ) = ( $event->x, $event->y );
    my $allocation = $self->get_allocation;

    if ( $offset->{x} > 0 ) { $offset->{x} = 0 }
    elsif ( $offset->{width} + $offset->{x} < $allocation->{width} ) {
        $offset->{x} = $allocation->{width} - $offset->{width};
    }
    if ( $offset->{y} > 0 ) { $offset->{y} = 0 }
    elsif ( $offset->{height} + $offset->{y} < $allocation->{height} ) {
        $offset->{y} = $allocation->{height} - $offset->{height};
    }

    $self->set( 'offset', $offset );
    my $win = $self->get_window();
    $win->invalidate_rect( $allocation, FALSE );
    return;
}

sub _scroll {
    my ( $self, $event ) = @_;
    if ( $event->direction eq 'up' ) {
        $self->zoom_in;
    }
    else {
        $self->zoom_out;
    }
    return;
}

sub _draw {
    my ( $self, $context ) = @_;
    my $zoom = $self->get_zoom;
    $context->scale( $zoom, $zoom );

    # Create pixbuf
    my $offset = $self->get('offset');

#    Gtk3::Gdk::Cairo($context, set_source_pixbuf( $self->get_pixbuf, $offset->{x},
#        $offset->{y} ));
    $context->set_source_surface( $self->get_pixbuf, $offset->{x},
        $offset->{y} );
    $context->paint;
    return TRUE;
}

sub set_zoom {
    my ( $self, $zoom ) = @_;
    $self->set( 'zoom', $zoom );
    my $win = $self->get_window();
    if ( defined $win ) {
        $win->invalidate_rect( $self->get_allocation, FALSE );
    }
    return;
}

sub get_zoom {
    my ($self) = @_;
    return $self->get('zoom');
}

sub zoom_to_fit {
    my ($self) = @_;
    my $pixbuf = $self->get('pixbuf');
    if ( not defined $pixbuf ) { return }
    my $allocation  = $self->get_allocation;
    my $offset      = $self->get('offset');
    my $sc_factor_w = $allocation->{width} / $offset->{width};
    my $sc_factor_h = $allocation->{height} / $offset->{height};
    $self->set( 'zoom', min( $sc_factor_w, $sc_factor_h ) );
    return;
}

sub zoom_in {
    my ($self) = @_;
    $self->set_zoom( $self->get_zoom * 2 );
    return;
}

sub zoom_out {
    my ($self) = @_;
    $self->set_zoom( $self->get_zoom / 2 );
    return;
}

1;
