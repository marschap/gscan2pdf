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
use Readonly;
Readonly my $HALF => 0.5;

our $VERSION = '1.8.11';

use Glib::Object::Subclass Gtk3::DrawingArea::, signals => {
    'zoom-changed' => {
        param_types => ['Glib::Float'],    # new zoom
    },
  },
  properties => [
    Glib::ParamSpec->object(
        'pixbuf',                           # name
        'pixbuf',                           # nickname
        'Gtk3::Gdk::Pixbuf to be shown',    # blurb
        'Gtk3::Gdk::Pixbuf',
        [qw/readable writable/]             # flags
    ),
    Glib::ParamSpec->scalar(
        'offset',                           # name
        'Image offset',                     # nick
        'Gdk::Rectangle hash of x, y',      # blurb
        [qw/readable writable/]             # flags
    ),
    Glib::ParamSpec->float(
        'zoom',                             # name
        'zoom',                             # nick
        'zoom level',                       # blurb
        0.001,                              # minimum
        1000.0,                             # maximum
        1.0,                                # default_value
        [qw/readable writable/]             # flags
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
    $self->set( 'pixbuf', $pixbuf );
    if ($zoom_to_fit) {
        $self->zoom_to_fit;
    }
    else {
        $self->set_offset( 0, 0 );
    }
    return;
}

sub get_pixbuf {
    my ($self) = @_;
    return $self->get('pixbuf');
}

sub get_pixbuf_size {
    my ($self) = @_;
    my $pixbuf = $self->get_pixbuf;
    if ( defined $pixbuf ) {
        return { width => $pixbuf->get_width, height => $pixbuf->get_height };
    }
    return;
}

sub get_zoomed_size {
    my ($self) = @_;
    my $size = $self->get_pixbuf_size;
    if ( defined $size ) {
        my $zoom = $self->get_zoom;
        return {
            width  => int( $size->{width} * $zoom + $HALF ),
            height => int( $size->{height} * $zoom + $HALF )
        };
    }
    return;
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

    my $offset = $self->get_offset;
    my $zoom   = $self->get_zoom;
    $offset->{x} += ( $event->x - $self->{pan_start}{x} ) / $zoom;
    $offset->{y} += ( $event->y - $self->{pan_start}{y} ) / $zoom;
    ( $self->{pan_start}{x}, $self->{pan_start}{y} ) = ( $event->x, $event->y );

    $self->set_offset( $offset->{x}, $offset->{y} );
    return;
}

sub _scroll {
    my ( $self, $event ) = @_;
    my ( $center_x, $center_y ) =
      $self->_to_image_coords( $event->x, $event->y );
    my $zoom;
    if ( $event->direction eq 'up' ) {
        $zoom = $self->get_zoom * 2;
    }
    else {
        $zoom = $self->get_zoom / 2;
    }
    $self->_set_zoom_with_center( $zoom, $center_x, $center_y );
    return;
}

sub _draw {
    my ( $self, $context ) = @_;
    my $zoom = $self->get_zoom;
    $context->scale( $zoom, $zoom );

    # Create pixbuf
    my $pixbuf = $self->get_pixbuf;
    if ( defined $pixbuf ) {
        my $offset = $self->get_offset;
        Gtk3::Gdk::cairo_set_source_pixbuf( $context, $pixbuf, $offset->{x},
            $offset->{y} );
        $context->paint;
    }
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

# convert x, y in image coords to widget coords
sub _to_widget_coords {
    my ( $self, $x, $y ) = @_;
    my $zoom   = $self->get_zoom;
    my $offset = $self->get_offset;
    return ( $x + $offset->{x} ) * $zoom, ( $y + $offset->{y} ) * $zoom;
}

# convert x, y in widget coords to image coords
sub _to_image_coords {
    my ( $self, $x, $y, $zoom ) = @_;
    if ( not defined $zoom ) { $zoom = $self->get_zoom }
    my $offset = $self->get_offset;
    return $x / $zoom - $offset->{x}, $y / $zoom - $offset->{y};
}

# set zoom with centre in image coordinates
sub _set_zoom_with_center {
    my ( $self, $zoom, $center_x, $center_y ) = @_;
    my $allocation = $self->get_allocation;
    my $offset_x   = $allocation->{width} / 2 / $zoom - $center_x;
    my $offset_y   = $allocation->{height} / 2 / $zoom - $center_y;
    $self->set_zoom($zoom);
    $self->set_offset( $offset_x, $offset_y );
    return;
}

# sets zoom, centred on the viewport
sub _set_zoom_no_center {
    my ( $self, $zoom ) = @_;
    my $allocation = $self->get_allocation;
    my ( $center_x, $center_y ) =
      $self->_to_image_coords( $allocation->{width} / 2,
        $allocation->{height} / 2 );
    $self->_set_zoom_with_center( $zoom, $center_x, $center_y );
    return;
}

sub zoom_to_fit {
    my ($self) = @_;
    my $pixbuf_size = $self->get_pixbuf_size;
    if ( not defined $pixbuf_size ) { return }
    my $allocation  = $self->get_allocation;
    my $sc_factor_w = $allocation->{width} / $pixbuf_size->{width};
    my $sc_factor_h = $allocation->{height} / $pixbuf_size->{height};
    $self->_set_zoom_with_center(
        min( $sc_factor_w, $sc_factor_h ),
        $pixbuf_size->{width} / 2,
        $pixbuf_size->{height} / 2
    );
    return;
}

sub zoom_in {
    my ($self) = @_;
    $self->_set_zoom_no_center( $self->get_zoom * 2 );
    return;
}

sub zoom_out {
    my ($self) = @_;
    $self->_set_zoom_no_center( $self->get_zoom / 2 );
    return;
}

sub set_offset {
    my ( $self, $offset_x, $offset_y ) = @_;

    #    my $allocation  = $self->get_allocation;
    #    my $pixbuf_size = $self->get_pixbuf_size;
    #    if ( $offset_x < 0 ) { $offset_x = 0 }
    #    elsif ( $allocation->{width} + $offset_x > $pixbuf_size->{width} ) {
    #        $offset_x = $pixbuf_size->{width} - $allocation->{width};
    #    }
    #    if ( $offset_y < 0 ) { $offset_y = 0 }
    #    elsif ( $allocation->{height} + $offset_y > $pixbuf_size->{height} ) {
    #        $offset_y = $pixbuf_size->{height} - $allocation->{height};
    #    }

    $self->set( 'offset', { x => $offset_x, y => $offset_y } );
    my $win = $self->get_window();
    if ( defined $win ) {
        $win->invalidate_rect( $self->get_allocation, FALSE );
    }
    return;
}

sub get_offset {
    my ($self) = @_;
    return $self->get('offset');
}

sub get_viewport {
    my ($self)     = @_;
    my $allocation = $self->get_allocation;
    my $zoomed     = $self->get_zoomed_size;
    my $offset     = $self->get_offset;
    if ( defined $zoomed ) {
        return {
            x      => $offset->{x},
            y      => $offset->{y},
            width  => min( $allocation->{width}, $zoomed->{width} ),
            height => min( $allocation->{height}, $zoomed->{height} )
        };
    }
    return;
}

1;
