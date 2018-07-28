package Gscan2pdf::Dialog;

use warnings;
use strict;
use Gtk3;
use Glib 1.220 qw(TRUE FALSE);    # To get TRUE and FALSE
use Data::Dumper;
$Data::Dumper::Sortkeys = 1;

use Glib::Object::Subclass Gtk3::Window::,
  signals => {
    delete_event    => \&on_delete_event,
    key_press_event => \&on_key_press_event,
  },
  properties => [
    Glib::ParamSpec->uint(
        'border-width',             # name
        'Border width',             # nickname
        'Border width for vbox',    # blurb
        0,                          # min
        999,                        # max
        0,                          # default
        [qw/readable writable/]     # flags
    ),
    Glib::ParamSpec->boolean(
        'hide-on-delete',                                             # name
        'Hide on delete',                                             # nickname
        'Whether to destroy or hide the dialog when it is dismissed', # blurb
        FALSE,                                                        # default
        [qw/readable writable/]                                       # flags
    ),
    Glib::ParamSpec->object(
        'vbox',                                                       # name
        'VBox',                                                       # nickname
        'VBox which is automatically added to the Gscan2pdf::Dialog', # blurb
        'Gtk3::VBox',                                                 # package
        [qw/readable writable/]                                       # flags
    ),
  ];

our $VERSION = '2.1.3';
my $EMPTY    = q{};
my $HEXREGEX = qr{^(.*)           # start of message
                  \b0x[[:xdigit:]]+\b # hex (e.g. address)
                  (.*)$           # rest of message
                 }xsm;
my $INTREGEX = qr{^(.*)           # start of message
                  \b[[:digit:]]+\b # integer
                  (.*)$           # rest of message
                 }xsm;

sub INIT_INSTANCE {
    my $self = shift;

    $self->set_position('center-on-parent');

    # VBox for window
    my $vbox = Gtk3::VBox->new;
    $self->add($vbox);
    $self->set( 'vbox', $vbox );
    return $self;
}

sub SET_PROPERTY {
    my ( $self, $pspec, $newval ) = @_;
    my $name = $pspec->get_name;
    $self->{$name} = $newval;
    if ( $name eq 'border_width' ) {
        $self->get('vbox')->set( 'border-width', $newval );
    }
    return;
}

sub on_delete_event {
    my ( $widget, $event ) = @_;
    if ( $widget->get('hide-on-delete') ) {
        $widget->hide;
        return Gtk3::EVENT_STOP;    # ensures that the window is not destroyed
    }
    $widget->destroy;
    return Gtk3::EVENT_PROPAGATE;
}

sub on_key_press_event {
    my ( $widget, $event ) = @_;
    if ( $event->keyval != Gtk3::Gdk::KEY_Escape ) {
        $widget->signal_chain_from_overridden($event);
        return Gtk3::EVENT_PROPAGATE;
    }
    if ( $widget->get('hide-on-delete') ) {
        $widget->hide;
    }
    else {
        $widget->destroy;
    }
    return Gtk3::EVENT_STOP;
}

sub dump_or_stringify {
    my ($val) = @_;
    return (
        defined $val
        ? ( ref($val) eq $EMPTY ? $val : Dumper($val) )
        : 'undef'
    );
}

# External tools sometimes throws warning messages including a number,
# e.g. hex address. As the number is very rarely the same, although the message
# itself is, filter out the number from the message

sub filter_message {
    my ($message) = @_;
    while ( $message =~ /$HEXREGEX/xsmo ) {
        $message =~ s/$HEXREGEX/$1%%x$2/xsmo;
    }
    while ( $message =~ /$INTREGEX/xsmo ) {
        $message =~ s/$INTREGEX/$1%%d$2/xsmo;
    }
    return $message;
}

1;

__END__
