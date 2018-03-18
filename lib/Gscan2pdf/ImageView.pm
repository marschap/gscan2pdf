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

our $VERSION = '2.0.1';

# Note: in a BEGIN block to ensure that the registration is complete
#       by the time the use Subclass goes to look for it.
BEGIN {
    Glib::Type->register_enum( 'Gscan2pdf::ImageView::Tool',
        qw(dragger selector) );
}

use Glib::Object::Subclass Gtk3::DrawingArea::, signals => {
    'zoom-changed' => {
        param_types => ['Glib::Float'],    # new zoom
    },
    'offset-changed' => {
        param_types => [ 'Glib::Int', 'Glib::Int' ],    # new offset
    },
    'selection-changed' => {
        param_types => ['Glib::Scalar'],    # Gdk::Rectangle of selection area
    },
    'tool-changed' => {
        param_types => ['Glib::String'],    # new tool
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
    Glib::ParamSpec->enum(
        'tool',                                 # name
        'tool',                                 # nickname
        'Active Gscan2pdf::ImageView::Tool',    # blurb
        'Gscan2pdf::ImageView::Tool',
        'dragger',                              # default
        [qw/readable writable/]                 #flags
    ),
    Glib::ParamSpec->scalar(
        'selection',                                 # name
        'Selection',                                 # nick
        'Gdk::Rectangle hash of selected region',    # blurb
        [qw/readable writable/]                      # flags
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
    $self->set_tool('dragger');
    return $self;
}

sub SET_PROPERTY {
    my ( $self, $pspec, $newval ) = @_;
    my $name       = $pspec->get_name;
    my $oldval     = $self->get($name);
    my $invalidate = FALSE;
    if (   ( defined $newval and defined $oldval and $newval ne $oldval )
        or ( defined $newval xor defined $oldval ) )
    {
        given ($name) {
            when ('pixbuf') {
                $self->{$name} = $newval;
                if ( not defined $newval ) {
                    $invalidate = TRUE;
                }
            }
            when ('zoom') {
                $self->{$name} = $newval;
                $self->signal_emit( 'zoom-changed', $newval );
                $invalidate = TRUE;
            }
            when ('offset') {
                if (   ( defined $newval xor defined $oldval )
                    or $oldval->{x} != $newval->{x}
                    or $oldval->{y} != $newval->{y} )
                {
                    $self->{$name} = $newval;
                    $self->signal_emit( 'offset-changed', $newval->{x},
                        $newval->{y} );
                    $invalidate = TRUE;
                }
            }
            when ('selection') {
                if (   ( defined $newval xor defined $oldval )
                    or $oldval->{x} != $newval->{x}
                    or $oldval->{y} != $newval->{y}
                    or $oldval->{width} != $newval->{width}
                    or $oldval->{height} != $newval->{height} )
                {
                    $self->{$name} = $newval;
                    if ( $self->get_tool eq 'selector' ) {
                        $invalidate = TRUE;
                    }
                    $self->signal_emit( 'selection-changed', $newval );
                }
            }
            when ('tool') {
                $self->{$name} = $newval;
                if ( defined $self->get_selection ) {
                    $invalidate = TRUE;
                }
                $self->signal_emit( 'tool-changed', $newval );
            }
            default {
                $self->{$name} = $newval;

                #                $self->SUPER::SET_PROPERTY( $pspec, $newval );
            }
        }
        if ($invalidate) {
            my $win = $self->get_window();
            if ( defined $win ) {
                $win->invalidate_rect( $self->get_allocation, FALSE );
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

    $self->{drag_start} = { x => $event->x, y => $event->y };
    $self->{dragging} = TRUE;
    return TRUE;
}

sub _button_released {
    my ( $self, $event ) = @_;
    $self->{dragging} = FALSE;
    return;
}

sub _motion {
    my ( $self, $event ) = @_;
    if ( not $self->{dragging} ) { return FALSE }

    if ( $self->get_tool eq 'dragger' ) {
        my $offset = $self->get_offset;
        my $zoom   = $self->get_zoom;
        my $offset_x =
          $offset->{x} + ( $event->x - $self->{drag_start}{x} ) / $zoom;
        my $offset_y =
          $offset->{y} + ( $event->y - $self->{drag_start}{y} ) / $zoom;
        ( $self->{drag_start}{x}, $self->{drag_start}{y} ) =
          ( $event->x, $event->y );
        $self->set_offset( $offset_x, $offset_y );
    }
    elsif ( $self->get_tool eq 'selector' ) {

        # calculate the rectangle, give it the right orientation
        my $x = int( min( $self->{drag_start}{x}, $event->x ) );
        my $y = int( min( $self->{drag_start}{y}, $event->y ) );
        my $w = int( abs( $self->{drag_start}{x} - $event->x ) );
        my $h = int( abs( $self->{drag_start}{y} - $event->y ) );
        ( $x, $y ) = $self->_to_image_coords( $x, $y );
        ( $w, $h ) = $self->_to_image_distance( $w, $h );
        $self->set_selection( { x => $x, y => $y, width => $w, height => $h } );
    }
    return;
}

sub _scroll {
    my ( $self, $event ) = @_;
    if ( $self->get_tool ne 'dragger' ) { return }
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
    my $allocation = $self->get_allocation;
    my $style      = $self->get_style_context;
    my $pixbuf     = $self->get_pixbuf;
    my ( $x, $y, $w, $h );
    if ( defined $pixbuf ) {
        my $zoom = $self->get_zoom;
        $context->scale( $zoom, $zoom );
        my $offset = $self->get_offset;
        $context->translate( $offset->{x}, $offset->{y} );
        ( $x, $y, $w, $h ) = (
            $self->_to_image_coords( 0, 0 ),
            $self->_to_image_coords(
                $allocation->{width}, $allocation->{height}
            )
        );
    }
    else {
        ( $x, $y, $w, $h ) =
          ( 0, 0, $allocation->{width}, $allocation->{height} );
    }
    $style->save;
    $style->add_class(Gtk3::STYLE_CLASS_BACKGROUND);
    Gtk3::render_background( $style, $context, $x, $y, $w, $h );
    $style->restore;
    if ( defined $pixbuf ) {
        Gtk3::Gdk::cairo_set_source_pixbuf( $context, $pixbuf, 0, 0 );
    }
    else {
        my $bgcol = $style->get( 'normal', 'background-color' );
        Gtk3::Gdk::cairo_set_source_rgba( $context, $bgcol );
    }
    $context->paint;

    if ( defined $pixbuf and $self->get_tool eq 'selector' ) {
        my $selection = $self->get_selection;
        if ( defined $selection ) {
            ( $x, $y, $w, $h, ) = (
                $selection->{x},     $selection->{y},
                $selection->{width}, $selection->{height},
            );
            if ( $w <= 0 or $h <= 0 ) { return TRUE }

            $style->save;
            $style->add_class(Gtk3::STYLE_CLASS_RUBBERBAND);
            Gtk3::render_background( $style, $context, $x, $y, $w, $h );
            Gtk3::render_frame( $style, $context, $x, $y, $w, $h );
            $style->restore;
        }
    }
    return TRUE;
}

sub set_zoom {
    my ( $self, $zoom ) = @_;
    $self->set( 'zoom', $zoom );
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
    my ( $self, $x, $y ) = @_;
    my $zoom   = $self->get_zoom;
    my $offset = $self->get_offset;
    return $x / $zoom - $offset->{x}, $y / $zoom - $offset->{y};
}

# convert x, y in widget distance to image distance
sub _to_image_distance {
    my ( $self, $x, $y ) = @_;
    my $zoom = $self->get_zoom;
    return $x / $zoom, $y / $zoom;
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

sub _clamp_direction {
    my ( $offset, $allocation, $pixbuf_size ) = @_;

    # Centre the image if it is smaller than the widget
    if ( $allocation > $pixbuf_size ) {
        $offset = ( $allocation - $pixbuf_size ) / 2;
    }

    # Otherwise don't allow the LH/top edge of the image to be visible
    elsif ( $offset > 0 ) {
        $offset = 0;
    }

    # Otherwise don't allow the RH/bottom edge of the image to be visible
    elsif ( $offset < $allocation - $pixbuf_size ) {
        $offset = $allocation - $pixbuf_size;
    }
    return $offset;
}

sub set_offset {
    my ( $self, $offset_x, $offset_y ) = @_;
    if ( not defined $self->get_pixbuf ) { return }

    # Convert the widget size to image scale to make the comparisons easier
    my $allocation = $self->get_allocation;
    ( $allocation->{width}, $allocation->{height} ) =
      $self->_to_image_distance( $allocation->{width}, $allocation->{height} );
    my $pixbuf_size = $self->get_pixbuf_size;

    $offset_x = _clamp_direction( $offset_x, $allocation->{width},
        $pixbuf_size->{width} );
    $offset_y = _clamp_direction( $offset_y, $allocation->{height},
        $pixbuf_size->{height} );

    $self->set( 'offset', { x => $offset_x, y => $offset_y } );
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

sub set_tool {
    my ( $self, $tool ) = @_;
    $self->set( 'tool', $tool );
    return;
}

sub get_tool {
    my ($self) = @_;
    return $self->get('tool');
}

sub set_selection {
    my ( $self, $selection ) = @_;
    my $pixbuf_size = $self->get_pixbuf_size;
    if ( not defined $pixbuf_size ) { return }
    if ( $selection->{x} < 0 ) {
        $selection->{width} += $selection->{x};
        $selection->{x} = 0;
    }
    if ( $selection->{y} < 0 ) {
        $selection->{height} += $selection->{y};
        $selection->{y} = 0;
    }
    if ( $selection->{x} + $selection->{width} > $pixbuf_size->{width} ) {
        $selection->{width} = $pixbuf_size->{width} - $selection->{x};
    }
    if ( $selection->{y} + $selection->{height} > $pixbuf_size->{height} ) {
        $selection->{height} = $pixbuf_size->{height} - $selection->{y};
    }
    $self->set( 'selection', $selection );
    return;
}

sub get_selection {
    my ($self) = @_;
    return $self->get('selection');
}

1;
