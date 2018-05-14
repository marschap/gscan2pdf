package Gscan2pdf::Dialog;

use warnings;
use strict;
use Gtk3;
use Glib 1.220 qw(TRUE FALSE);      # To get TRUE and FALSE
use Gscan2pdf::Document;
use Gscan2pdf::EntryCompletion;
use Gscan2pdf::Translation '__';    # easier to extract strings with xgettext
use Date::Calc qw(Add_Delta_Days Today);
use Data::Dumper;
$Data::Dumper::Sortkeys = 1;
use Readonly;
Readonly my $ENTRY_WIDTH => 10;

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

our $VERSION = '2.1.1';
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

sub add_metadata_dialog {
    my ( $self, $defaults ) = @_;
    my ($vbox) = $self->get('vbox');

    # it needs its own box to be able to hide it if necessary
    my $hboxmd = Gtk3::HBox->new;
    $vbox->pack_start( $hboxmd, FALSE, FALSE, 0 );

    # Frame for metadata
    my $frame = Gtk3::Frame->new( __('Document Metadata') );
    $hboxmd->pack_start( $frame, TRUE, TRUE, 0 );
    my $vboxm = Gtk3::VBox->new;
    $vboxm->set_border_width( $self->get('border-width') );
    $frame->add($vboxm);

    # grid to align widgets
    my $grid = Gtk3::Grid->new;
    $vboxm->pack_start( $grid, TRUE, TRUE, 0 );

    # Date/time
    my $hboxe = Gtk3::HBox->new;
    my $row   = 0;
    $grid->attach( $hboxe, 0, $row, 1, 1 );
    my $labele = Gtk3::Label->new( __('Date') );
    $hboxe->pack_start( $labele, FALSE, TRUE, 0 );

    my $entryd = Gtk3::Entry->new;
    $entryd->set_max_length($ENTRY_WIDTH);
    $entryd->set_text(
        Gscan2pdf::Document::expand_metadata_pattern(
            template      => '%Y-%m-%d',
            today_and_now => [
                Add_Delta_Days(
                    @{ $defaults->{date}{today} },
                    $defaults->{date}{offset}
                )
            ]
        )
    );
    $entryd->set_activates_default(TRUE);
    $entryd->set_tooltip_text( __('Year-Month-Day') );
    $entryd->set_alignment(1.);    # Right justify
    $entryd->signal_connect( 'insert-text' => \&insert_text_handler );
    $entryd->signal_connect(
        'focus-out-event' => sub {
            my $text = $entryd->get_text;
            if ( defined $text and $text ne $EMPTY ) {
                $entryd->set_text( sprintf '%04d-%02d-%02d',
                    Gscan2pdf::Document::text_to_date($text) );
            }
            return FALSE;
        }
    );
    my $button = Gtk3::Button->new;
    $button->set_image( Gtk3::Image->new_from_stock( 'gtk-edit', 'button' ) );
    $button->signal_connect(
        clicked => sub {
            my $window_date = Gscan2pdf::Dialog->new(
                'transient-for' => $self,
                title           => __('Select Date'),
                border_width    => $self->get('border-width')
            );
            my $vbox_date = $window_date->get('vbox');
            $window_date->set_resizable(FALSE);
            my $calendar = Gtk3::Calendar->new;

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

            my $today = Gtk3::Button->new( __('Today') );
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
    $button->set_tooltip_text( __('Select date with calendar') );
    $hboxe = Gtk3::HBox->new;
    $grid->attach( $hboxe, 1, $row++, 1, 1 );
    $hboxe->pack_end( $button, FALSE, FALSE, 0 );
    $hboxe->pack_end( $entryd, FALSE, FALSE, 0 );

    my @label = (
        { title    => __('Title') },
        { author   => __('Author') },
        { subject  => __('Subject') },
        { keywords => __('Keywords') },
    );
    my %widgets = (
        box  => $hboxmd,
        date => $entryd,
    );
    for my $entry (@label) {
        my ( $name, $label ) = %{$entry};
        my $hbox = Gtk3::HBox->new;
        $grid->attach( $hbox, 0, $row, 1, 1 );
        $label = Gtk3::Label->new($label);
        $hbox->pack_start( $label, FALSE, TRUE, 0 );
        $hbox = Gtk3::HBox->new;
        $grid->attach( $hbox, 1, $row++, 1, 1 );
        my $entry =
          Gscan2pdf::EntryCompletion->new( $defaults->{$name}{default},
            $defaults->{$name}{suggestions} );
        $hbox->pack_start( $entry, TRUE, TRUE, 0 );
        $widgets{$name} = $entry;
    }
    return %widgets;
}

sub insert_text_handler {
    my ( $widget, $string, $len, $position ) = @_;

    # only allow integers and -
    if ( $string =~ /^[\d\-]+$/smx ) {
        $widget->signal_handlers_block_by_func( \&insert_text_handler );
        $widget->insert_text( $string, $len, $position++ );
        $widget->signal_handlers_unblock_by_func( \&insert_text_handler );
    }
    $widget->signal_stop_emission_by_name('insert-text');
    return $position;
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
