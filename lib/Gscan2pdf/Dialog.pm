package Gscan2pdf::Dialog;

use warnings;
use strict;
use Gtk2;
use Glib 1.220 qw(TRUE FALSE);    # To get TRUE and FALSE
use Gtk2::Gdk::Keysyms;
use Gscan2pdf::Document;
use Gscan2pdf::EntryCompletion;
use Date::Calc qw(Add_Delta_Days Today);
use Data::Dumper;
use Readonly;
Readonly my $ENTRY_WIDTH => 10;

use Glib::Object::Subclass Gtk2::Window::,
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
        'Gtk2::VBox',                                                 # package
        [qw/readable writable/]                                       # flags
    ),
  ];

our $VERSION = '1.7.3';
my $EMPTY = q{};
my ( $d, $tooltips );

sub INIT_INSTANCE {
    my $self = shift;

    $self->set_position('center-on-parent');
    $d        = Locale::gettext->domain(Glib::get_application_name);
    $tooltips = Gtk2::Tooltips->new;
    $tooltips->enable;

    # VBox for window
    my $vbox = Gtk2::VBox->new;
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
        return Gtk2::EVENT_STOP;    # ensures that the window is not destroyed
    }
    $widget->destroy;
    return Gtk2::EVENT_PROPAGATE;
}

sub on_key_press_event {
    my ( $widget, $event ) = @_;
    if ( $event->keyval !=
        $Gtk2::Gdk::Keysyms{Escape} )    ## no critic (ProhibitPackageVars)
    {
        $widget->signal_chain_from_overridden($event);
        return Gtk2::EVENT_PROPAGATE;
    }
    if ( $widget->get('hide-on-delete') ) {
        $widget->hide;
    }
    else {
        $widget->destroy;
    }
    return Gtk2::EVENT_STOP;
}

sub add_metadata_dialog {
    my ( $self, $defaults ) = @_;
    my ($vbox) = $self->get('vbox');

    # it needs its own box to be able to hide it if necessary
    my $hboxmd = Gtk2::HBox->new;
    $vbox->pack_start( $hboxmd, FALSE, FALSE, 0 );

    # Frame for metadata
    my $frame = Gtk2::Frame->new( $d->get('Document Metadata') );
    $hboxmd->pack_start( $frame, TRUE, TRUE, 0 );
    my $vboxm = Gtk2::VBox->new;
    $vboxm->set_border_width( $self->get('border-width') );
    $frame->add($vboxm);

    # table-view
    my $table = Gtk2::Table->new( 5, 2 );    ## no critic (ProhibitMagicNumbers)
    $table->set_row_spacings( $self->get('border-width') );
    $vboxm->pack_start( $table, TRUE, TRUE, 0 );

    # Date/time
    my $hboxe = Gtk2::HBox->new;
    my $row   = 0;
    $table->attach( $hboxe, 0, 1, $row, $row + 1, 'fill', 'shrink', 0, 0 );
    my $labele = Gtk2::Label->new( $d->get('Date') );
    $hboxe->pack_start( $labele, FALSE, TRUE, 0 );

    my $entryd = Gtk2::Entry->new_with_max_length($ENTRY_WIDTH);
    $entryd->set_text(
        Gscan2pdf::Document::expand_metadata_pattern(
            '%Y-%M-%D',
            undef,
            undef, undef, undef,
            Add_Delta_Days(
                @{ $defaults->{date}{today} },
                $defaults->{date}{offset}
            )
        )
    );
    $entryd->set_activates_default(TRUE);
    $tooltips->set_tip( $entryd, $d->get('Year-Month-Day') );
    $entryd->set_alignment(1.);    # Right justify
    $entryd->signal_connect(
        'insert-text' => sub {
            my ( $widget, $string, $len, $position ) = @_;

            # only allow integers and -
            if ( $string !~ /^[\d\-]+$/smx ) {
                $entryd->signal_stop_emission_by_name('insert-text');
            }
            ()    # this callback must return either 2 or 0 items.
        }
    );
    $entryd->signal_connect(
        'focus-out-event' => sub {
            $entryd->set_text( sprintf '%04d-%02d-%02d',
                Gscan2pdf::Document::text_to_date( $entryd->get_text ) );
            return FALSE;
        }
    );
    my $button = Gtk2::Button->new;
    $button->set_image( Gtk2::Image->new_from_stock( 'gtk-edit', 'button' ) );
    $button->signal_connect(
        clicked => sub {
            my $window_date = Gscan2pdf::Dialog->new(
                'transient-for' => $self,
                title           => $d->get('Select Date'),
                border_width    => $self->get('border-width')
            );
            my $vbox_date = $window_date->get('vbox');
            $window_date->set_resizable(FALSE);
            my $calendar = Gtk2::Calendar->new;

            # Editing the entry and clicking the edit button bypasses the
            # focus-out-event, so update the date now
            my ( $year, $month, $day ) =
              Gscan2pdf::Document::text_to_date( $entryd->get_text );

            $calendar->select_day($day);
            $calendar->select_month( $month - 1, $year );
            my $calendar_s;
            $calendar_s = $calendar->signal_connect(
                day_selected => sub {
                    ( $year, $month, $day ) = $calendar->get_date;
                    $month += 1;
                    $entryd->set_text( sprintf '%04d-%02d-%02d',
                        $year, $month, $day );
                }
            );
            $calendar->signal_connect(
                day_selected_double_click => sub {
                    ( $year, $month, $day ) = $calendar->get_date;
                    $month += 1;
                    $entryd->set_text( sprintf '%04d-%02d-%02d',
                        $year, $month, $day );
                    $window_date->destroy;
                }
            );
            $vbox_date->pack_start( $calendar, TRUE, TRUE, 0 );

            my $today = Gtk2::Button->new( $d->get('Today') );
            $today->signal_connect(
                clicked => sub {
                    ( $year, $month, $day ) = Today();

                    # block and unblock signal, and update entry manually
                    # to remove possibility of race conditions
                    $calendar->signal_handler_block($calendar_s);
                    $calendar->select_day($day);
                    $calendar->select_month( $month - 1, $year );
                    $calendar->signal_handler_unblock($calendar_s);
                    $entryd->set_text( sprintf '%04d-%02d-%02d',
                        $year, $month, $day );
                }
            );
            $vbox_date->pack_start( $today, TRUE, TRUE, 0 );

            $window_date->show_all;
        }
    );
    $tooltips->set_tip( $button, $d->get('Select date with calendar') );
    $hboxe = Gtk2::HBox->new;
    $table->attach_defaults( $hboxe, 1, 2, $row, $row + 1 );
    $hboxe->pack_end( $button, FALSE, FALSE, 0 );
    $hboxe->pack_end( $entryd, FALSE, FALSE, 0 );

    my @label = (
        { title    => $d->get('Title') },
        { author   => $d->get('Author') },
        { subject  => $d->get('Subject') },
        { keywords => $d->get('Keywords') },
    );
    my %widgets = (
        box  => $hboxmd,
        date => $entryd,
    );
    for my $entry (@label) {
        my ( $name, $label ) = %{$entry};
        my $hbox = Gtk2::HBox->new;
        $table->attach( $hbox, 0, 1, ++$row, $row + 1, 'fill', 'shrink', 0, 0 );
        $label = Gtk2::Label->new($label);
        $hbox->pack_start( $label, FALSE, TRUE, 0 );
        $hbox = Gtk2::HBox->new;
        $table->attach_defaults( $hbox, 1, 2, $row, $row + 1 );
        my $entry =
          Gscan2pdf::EntryCompletion->new( $defaults->{$name}{default},
            $defaults->{$name}{suggestions} );
        $hbox->pack_start( $entry, TRUE, TRUE, 0 );
        $widgets{$name} = $entry;
    }
    return %widgets;
}

sub dump_or_stringify {
    my ($val) = @_;
    return (
        defined $val
        ? ( ref($val) eq $EMPTY ? $val : Dumper($val) )
        : 'undef'
    );
}

# Unpaper sometimes throws warning messages including a memory address.
# As the address is very rarely the same, although the message itself is,
# filter out the address from the message

sub filter_message {
    my ($message) = @_;
    my $regex = qr{^(.*)           # start of message
                  0x[[:xdigit:]]+ # hex address
                  (.*)$           # rest of message
                 }xsm;
    while ( $message =~ /$regex/xsmo ) {
        $message =~ s/$regex/$1%%x$2/xsmo;
    }
    return $message;
}

1;

__END__
