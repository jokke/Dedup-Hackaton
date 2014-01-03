package App::DDup::File;
use 5.010;
use Moose;
use namespace::autoclean;
use Class::Load ':all';
use File::Compare;
use App::DDup::Settings;
use Carp qw/confess carp/;

our $VERSION = '0.001';

has settings => (
    is       => 'rw',
    isa      => 'App::DDup::Settings',
    required => 1,
);

has path => (
    is       => 'rw',
    isa      => 'Str',
    required => 1,
);

has inode => (
    is       => 'rw',
    isa      => 'Int',
    required => 1,
);

has size => (
    is       => 'rw',
    isa      => 'Int',
    required => 1,
);

has duplicate => (
    is        => 'rw',
    isa       => 'App::DDup::File',
    predicate => 'is_duplicate',
);

has digest => (
    is        => 'rw',
    lazy      => 1,
    builder   => 'build_digest',
    predicate => 'has_digest',
    clearer   => 'clear_digest',
);

has head => (
    is        => 'rw',
    lazy      => 1,
    builder   => 'build_head',
    predicate => 'has_head',
    clearer   => 'clear_head',
);

sub build_digest {
    my $self = shift;

    my $data;
    my $alg = $self->settings->checksum;
    load_class $alg;
    my $digest = $alg eq q{Digest::xxHash} ? $alg->new(0) : $alg->new;

    my $offset = 0;

    if ( $self->has_head ) {
        $digest->add( $self->head );
        $offset = length( $self->head );
    }

    open my $fh, q{<}, $self->path
      or ( carp q{Cannot open file } . $self->path and return 0 );
    binmode $fh;

    while ( my $len = read $fh, $data, $self->settings->block_size, $offset ) {
        $digest->add($data);
        $offset = 0;
    }

    close $fh
      or carp q{Cannot close file handle for } . $self->path;

    return $digest->digest;
}

sub build_head {
    my $self = shift;

    my $data;

    open my $fh, '<', $self->path
      or ( carp q{Cannot open file } . $self->path and return 0 );
    binmode $fh;

    read $fh, $data, $self->settings->head_size;

    close $fh
      or carp q{Cannot close file handle for } . $self->path;

    if ( $data and ( $self->size ) <= $self->settings->head_size ) {
        $self->digest($data);
    }

    return $data;
}

sub find_duplicates {
    my ( $self, @files ) = @_;

    return () if $self->is_duplicate;    # don't compare if self is duplicate

    if ( $self->size == 0 ) {            # assuming that zero sized are the same
        return map { $_->duplicate($self) } @files;
    }

    if ( scalar(@files) == 1 and not $files[0]->has_digest ) {
        if (
            File::Compare::compare( $self->path, $files[0]->path,
                $self->settings->block_size ) == 0
          )
        {
            $files[0]->duplicate($self);

            # return the duplicate
            return @files;
        }
        else {
            # only 2 two compare and not duplicates, so return empty list
            return ();
        }
    }
    my @duplicates;
    for my $f (@files) {
        next if $f->is_duplicate;    # already marked as duplicate

        # first, compare with head of file then the digest
        if ( $self->head ne $f->head or $self->digest ne $f->digest ) {
            next;
        }

        # must be a duplicate of self so add it to the list
        $f->duplicate($self);
        $f->clear_head;              # to save some RAM
        $f->clear_digest;            # to save some RAM
        push @duplicates, $f;
    }
    return @duplicates;
}

sub remove {
    my $self = shift;

    if ( $self->settings->remove ) {
        unlink $self->path
          or confess q{Unable to remove } . $self->path;
    }
    return 1;
}

__PACKAGE__->meta->make_immutable;

1;
