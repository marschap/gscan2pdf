package Gscan2pdf::Dialog::Renumber;

use strict;
use warnings;
use Glib 1.220 qw(TRUE FALSE);    # To get TRUE and FALSE
use Gscan2pdf::Dialog;
use Gscan2pdf::Document;
use Gscan2pdf::PageRange;

use Glib::Object::Subclass Gscan2pdf::Dialog::, signals => {
 'changed-start' => {
  param_types => ['Glib::UInt'],    # new start page
 },
 'changed-increment' => {
  param_types => ['Glib::Int'],     # new increment
 },
 'changed-document' => {
  param_types => ['Glib::Scalar'],    # new document
 },
 'changed-range' => {
  param_types => ['Gscan2pdf::PageRange::Range'],    # new range
 },
 'before-renumber' => { param_types => [], },
  },
  properties => [
 Glib::ParamSpec->int(
  'start',                                           # name
  'Number of first page',                            # nickname
  'Number of first page',                            # blurb
  1,                                                 # min
  999,                                               # max
  1,                                                 # default
  [qw/readable writable/]                            # flags
 ),
 Glib::ParamSpec->int(
  'increment',                                                        # name
  'Increment',                                                        # nickname
  'Amount to increment page number when renumbering multiple pages',  # blurb
  -99,                                                                # min
  99,                                                                 # max
  1,                                                                  # default
  [qw/readable writable/]                                             # flags
 ),
 Glib::ParamSpec->scalar(
  'document',                                                         # name
  'Document',                                                         # nick
  'Gscan2pdf::Document object to renumber',                           # blurb
  [qw/readable writable/]                                             # flags
 ),
 Glib::ParamSpec->enum(
  'range',                                                            # name
  'Page Range to renumber',                                           # nickname
  'Page Range to renumber',                                           #blurb
  'Gscan2pdf::PageRange::Range',
  'selected',                                                         # default
  [qw/readable writable/]                                             #flags
 ),
  ];

my ( $start_old, $step_old );

# Normally, we would initialise the widget in INIT_INSTANCE and use the
# default constructor new(). However, we have to override the default contructor
# in order to be able to access any properties assigned in ->new(), which are
# not available in INIT_INSTANCE. Therefore, we use the default INIT_INSTANCE,
# and override new(). If we ever need to subclass Gscan2pdf::Dialog::Renumber,
# then we would need to put the bulk of this code back into INIT_INSTANCE,
# and leave just that which assigns the required properties.

# Glib::Object::new takes the class as the first argument, so below is short
# for:
#  my $class = shift;
#  my $self = Glib::Object::new($class, @_);
sub new {    ## no critic (RequireArgUnpacking)
 my $self = Glib::Object::new(@_);

 my $d = Locale::gettext->domain(Glib::get_application_name);
 $self->set( 'title', $d->get('Renumber') );

 my $vbox = $self->get('vbox');

 # Frame for page range
 my $frame = Gtk2::Frame->new( $d->get('Page Range') );
 $vbox->pack_start( $frame, FALSE, FALSE, 0 );
 my $pr = Gscan2pdf::PageRange->new;
 $pr->signal_connect(
  changed => sub {
   $self->set( 'range', $pr->get_active );
   $self->update;
  }
 );
 $self->signal_connect(
  'changed-range' => sub {
   my ( $widget, $value ) = @_;
   $pr->set_active($value);
  }
 );
 $pr->set_active( $self->get('range') );
 $frame->add($pr);

 # Frame for page numbering
 my $framex = Gtk2::Frame->new( $d->get('Page numbering') );
 $vbox->pack_start( $framex, FALSE, FALSE, 0 );
 my $vboxx = Gtk2::VBox->new;
 $vboxx->set_border_width( $self->get('border_width') );
 $framex->add($vboxx);

 # SpinButton for starting page number
 my $hboxxs = Gtk2::HBox->new;
 $vboxx->pack_start( $hboxxs, FALSE, FALSE, 0 );
 my $labelxs = Gtk2::Label->new( $d->get('Start') );
 $hboxxs->pack_start( $labelxs, FALSE, FALSE, 0 );
 my $spin_buttons = Gtk2::SpinButton->new_with_range( 1, 99999, 1 );
 $spin_buttons->signal_connect(
  'value-changed' => sub {
   $self->set( 'start', $spin_buttons->get_value );
   $self->update;
  }
 );
 $self->signal_connect(
  'changed-start' => sub {
   my ( $widget, $value ) = @_;
   $spin_buttons->set_value($value);
  }
 );
 $spin_buttons->set_value( $self->get('start') );
 $hboxxs->pack_end( $spin_buttons, FALSE, FALSE, 0 );

 # SpinButton for page number increment
 my $hboxi = Gtk2::HBox->new;
 $vboxx->pack_start( $hboxi, FALSE, FALSE, 0 );
 my $labelxi = Gtk2::Label->new( $d->get('Increment') );
 $hboxi->pack_start( $labelxi, FALSE, FALSE, 0 );
 my $spin_buttoni = Gtk2::SpinButton->new_with_range( -99, 99, 1 );
 $spin_buttoni->signal_connect(
  'value-changed' => sub {
   $self->set( 'increment', $spin_buttoni->get_value );
   $self->update;
  }
 );
 $self->signal_connect(
  'changed-increment' => sub {
   my ( $widget, $value ) = @_;
   $spin_buttoni->set_value($value);
  }
 );
 $spin_buttoni->set_value( $self->get('increment') );
 $hboxi->pack_end( $spin_buttoni, FALSE, FALSE, 0 );

 # Check whether the settings are possible
 $self->signal_connect(
  'changed-document' => sub {
   $self->update;
  }
 );

 # HBox for buttons
 my $hbox = Gtk2::HBox->new;
 $vbox->pack_start( $hbox, FALSE, TRUE, 0 );

 # Start button
 my $obutton = Gtk2::Button->new( $d->get('Renumber') );
 $hbox->pack_start( $obutton, TRUE, TRUE, 0 );
 $obutton->signal_connect( clicked => sub { $self->renumber } );

 # Close button
 my $cbutton = Gtk2::Button->new_from_stock('gtk-close');
 $hbox->pack_end( $cbutton, FALSE, FALSE, 0 );
 $cbutton->signal_connect( clicked => sub { $self->hide; } );

 return $self;
}

sub SET_PROPERTY {
 my ( $self, $pspec, $newval ) = @_;
 my $name   = $pspec->get_name;
 my $oldval = $self->get($name);
 $self->{$name} = $newval;
 if (( defined($newval) and defined($oldval) and $newval ne $oldval )
  or ( defined($newval) xor defined($oldval) ) )
 {
  $self->signal_emit( "changed-$name", $newval );
 }
 return;
}

# Helper function to prevent impossible settings in renumber dialog

sub update {
 my ($self) = @_;

 my $start = $self->get('start');
 my $step  = $self->get('increment');

 my $dstart = defined($start_old) ? $start - $start_old : 0;
 my $dstep  = defined($step_old)  ? $step - $step_old   : 0;
 if ( $dstart == 0 and $dstep == 0 ) {
  $dstart = 1;
 }
 elsif ( $dstart != 0 and $dstep != 0 ) {
  $dstep = 0;
 }

 # Check for clash with non_selected
 my $slist = $self->get('document');
 if ( defined $slist ) {
  my $range = $self->get('range');
  while ( not $slist->valid_renumber( $start, $step, $range ) ) {
   my $n;
   if ( $range eq 'all' ) {
    $n = $#{ $slist->{data} };
   }
   else {
    my @page = $slist->get_selected_indices;
    $n = $#page;
   }

   if ( $start + $step * $n < 1 ) {
    if ( $dstart < 0 ) {
     $dstart = 1;
    }
    else {
     $dstep = 1;
    }
   }
   $start += $dstart;
   $step  += $dstep;
   $step  += $dstep if ( $step == 0 );
  }

  $self->set( 'start',     $start );
  $self->set( 'increment', $step );
 }
 $start_old = $start;
 $step_old  = $step;
 return;
}

sub renumber {
 my ($self) = @_;
 my $slist  = $self->get('document');
 my $start  = $self->get('start');
 my $step   = $self->get('increment');
 my $range  = $self->get('range');
 if ( $slist->valid_renumber( $start, $step, $range ) ) {

  $self->signal_emit('before-renumber');

  $slist->get_model->signal_handler_block( $slist->{row_changed_signal} )
    if ( defined $slist->{row_changed_signal} );
  $slist->renumber( $start, $step, $range );

  # Note selection before sorting
  my @page = $slist->get_selected_indices;

  # Convert to page numbers
  for (@page) {
   $_ = $slist->{data}[$_][0];
  }

# Block selection_changed_signal to prevent its firing changing pagerange to all
  $slist->get_selection->signal_handler_block(
   $slist->{selection_changed_signal} )
    if ( defined $slist->{selection_changed_signal} );

  # Select new page, deselecting others. This fires the select callback,
  # displaying the page
  $slist->get_selection->unselect_all;
  $slist->manual_sort_by_column(0);
  $slist->get_selection->signal_handler_unblock(
   $slist->{selection_changed_signal} )
    if ( defined $slist->{selection_changed_signal} );
  $slist->get_model->signal_handler_unblock( $slist->{row_changed_signal} )
    if ( defined $slist->{row_changed_signal} );

  # Convert back to indices
  for (@page) {

   # Due to the sort, must search for new page
   my $page = 0;
   ++$page
     while ( $page < $#{ $slist->{data} }
    and $slist->{data}[$page][0] != $_ );
   $_ = $page;
  }

  # Reselect pages
  $slist->select(@page);
 }
 else {
  my $d = Locale::gettext->domain(Glib::get_application_name);
  show_message_dialog(
   $self, 'error', 'close',
   $d->get(
'The current settings would result in duplicate page numbers. Please select new start and increment values.'
   )
  );
 }
 return;
}

1;

__END__
