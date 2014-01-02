package App::DDup;

use warnings FATAL => 'all';
use strict;

use 5.010;

use Benchmark ':hireswallclock';
use File::Find::Rule;
use POSIX qw|ceil floor log pow strftime|;

use threads;
use Thread::Queue;

use App::DDup::File;
use App::DDup::Settings;

our $VERSION = '0.001';

$VERSION = eval $VERSION;

sub import {
    $_[1] && $_[1] eq '-run_script' and run_script();
}

sub run_script {

    my $settings = App::DDup::Settings->new_with_options();

    say '** SCANNING ALL FILES';
    my $start_of_scan = Benchmark->new();

    my @candidates = scan_dir( $settings );

    say '** CHECKSUMMING SIZE DUPLICATES'; # To conform with reference print out

    my @duplicates;
    if ($settings->threads > 1) {
        @duplicates = get_sorted_duplicates_threads($settings, @candidates);
    } else {
        @duplicates = get_sorted_duplicates(@candidates);
    }

    my $end_of_scan = Benchmark->new();

    print_duplicates($settings, @duplicates);

    my ($total_bytes, $total_dups) = (0, 0);
    # delete if needed and calculate what we saved
    for my $dups (@duplicates) {
        $total_dups += scalar(@$dups) - 1;
        for my $i (1..$#$dups) { # all but the first "original" file
            $total_bytes += $dups->[$i]->size;
            $settings->remove and $dups->[$i]->remove;
        }
    }

    # print the footer
    say '-' x 30;
    say "** TOTAL DUPES:   $total_dups";
    say '** SAVED SPACE:   ' . friendly_size($total_bytes);
    say '** SCAN TIME:     ' . timestr timediff( $end_of_scan, $start_of_scan );
}

sub find_dups_threads {
    my $same_size_candidates = shift;
    my @duplicates;
    while (my $top = shift @$same_size_candidates) { # do n! comparasion
        $top->is_duplicate and next; # no need to find duplicates of a duplicate
        my @dups = $top->find_duplicates(@$same_size_candidates);
        # Would be more efficient to print duplicates here but need to store in RAM
        # for sorting and conform to competition rules
        if (scalar (@dups)) {
            push @duplicates, [ sort { $a->path cmp $b->path } $top, @dups ];
        }
    }
    return @duplicates;
}

sub get_sorted_duplicates_threads {
    my ($settings, @candidates) = @_;
    
    my $q = Thread::Queue->new();
    $q->enqueue($_) for @candidates;

    my @thr = map {
        threads->create(sub {
            my @duplicates;
            while (defined (my $same_size_candidates = $q->dequeue_nb())) {
                push @duplicates, find_dups_threads($same_size_candidates);
            }
            return @duplicates;
        });
    } 1..$settings->threads;

    my @all_duplicates;
    for my $t (@thr) {
        push @all_duplicates, $t->join;
    }
    return @all_duplicates;
}

sub get_sorted_duplicates {
    my @candidates = @_;
    my @duplicates;
    # find the actual duplicates in the candidate list - this for loop is the main work
    for my $i (0..$#candidates) {
        my $same_size_candidates = delete $candidates[$i];
        while (my $top = shift @$same_size_candidates) { # do n! comparasion
            $top->is_duplicate and next; # no need to find duplicates of a duplicate
            my @dups = $top->find_duplicates(@$same_size_candidates);
            # Would be more efficient to print duplicates here but need to store in RAM
            # for sorting and conform to competition rules
            if (scalar (@dups)) {
                push @duplicates, [ sort { $a->path cmp $b->path } $top, @dups ];
            }
        }
    }
    return @duplicates;
}

sub print_duplicates {
    my ($settings, @duplicates) = @_;

    say '** DISPLAYING OUTPUT';
    say '-' x 30;

    for my $dups (sort { $a->[0]->path cmp $b->[0]->path } @duplicates) {
        if ($settings->format eq 'robot') {
            say join "\t", map { $_->path } @$dups;
        } else { # human output
            say sprintf 'DUPLICATES (size: %sb)', friendly_size($dups->[0]->size);
            say "    $_" for @$dups;
        }
    }
}

sub friendly_size {
    my ($bytes) = @_;
    return "0B" unless $bytes;
    my @size_names = qw|B KB MB GB TB PB EB ZB YB|;
    my $e = floor(log($bytes)/log(1024));
    return sprintf("%.2f".$size_names[$e], ($bytes/pow(1024, floor($e))));
}


sub scan_dir {
    my $settings = shift;
    my %sorted_files; #sorted per size
    for my $file (File::Find::Rule          # loop over
                    ->file()                # all files
                    ->exec(sub { ! -l $_ }) # that are not symlinks
                    ->in($settings->dir)) { # in the specified directory 
        my (undef, $ino, undef, undef, undef, undef, undef, $size) = stat($file);
        # check if we already have a file with the inode, i.e. a hard link
        if (my ($f) = grep { $_->inode == $ino } @{$sorted_files{$size}->{files}}) {
            # use the "smallest" of the hardlinks, i.e. use file "a" rather than file "b"
            if (($file cmp $f->path) < 0) {
                $f->path($file);
            }
            next; # don't add the hard link
        }
        # add the file based on its size to an array for later comparation
        push @{$sorted_files{$size}->{files}}, App::DDup::File->new(
            path        => $file,
            inode       => $ino, 
            size        => $size,
            settings    => $settings,
        );
    }
    # populate candidates with array refs of same size of there is more than one
    my @candidates;
    for my $size (keys %sorted_files) {
        if (scalar (@{$sorted_files{$size}->{files}}) > 1) {
            push @candidates, $sorted_files{$size}->{files} ;
        }
    }
    return @candidates;
}

1;
