#!/usr/bin/perl

use warnings;
use strict;
use Getopt::Long;
use Pod::Usage;
use Carp qw(croak);
use File::Temp qw(tempfile);
use List::Util qw(shuffle);

sub ensure_readable_file {
  my $file = shift;

  if (! -e $file) {
    croak ('Error: ', $file, ' does not exist.');
  }
  if (! -f $file) {
    croak ('Error: ', $file, ' is not a file.');
  }

  if (! -r $file) {
    croak ('Error: ', $file, ' is unreadable.');
  }

  return 1;
}

my $help = 0;
my $man = 0;
my $table_file = undef;

GetOptions('help|?' => \$help,
           'man' => \$man,
	   'table=s' => \$table_file)
  or pod2usage(2);
pod2usage(1) if $help;
pod2usage(-exitstatus => 0, -verbose => 2) if $man;
# pod2usage(1) if (scalar @ARGV != 2);

if (! defined $table_file) {
  pod2usage (1);
}

ensure_readable_file ($table_file);

my %command_dispatch_table =
  ('all' => \&all,
   'dependent-items' => \&dependent_items,
   'explicitly-independent-items' => \&explicitly_independent_items,
   'implicitly-independent-items' => \&implicitly_independent_items,
   'independent-items' => \&independent_items,
   'dependencies-of' => \&dependencies_of,
   'items-depending-on' => \&items_depending_on,
   'random-item' => \&random_item,
   'dependencies-of-random-item' => \&dependencies_of_random_item,
   'topological-sort' => \&tsort,
   'items-independent-of' => \&items_independent_of,
   'used' => \&used,
   'unused' => \&unused,
   'sort' => \&sort_table,
   'shuffle' => \&shuffle_table,
   'complete' => \&complete_table,
   'invert' => \&invert_table);

if (scalar @ARGV == 0) {
  pod2usage (1);
}

my $command = $ARGV[0];
chomp $command;

if (! defined $command_dispatch_table{$command}) {
  pod2usage (1);
}

# Command line arguments seem to be valid; let's load the table.

my %table = ();
my %all_items = ();
my %dep_items = ();
my %trivial_dep_items = (); # items that explicitly have no dependencies
my %non_trivial_dep_items = (); # items that have at least item on which they depend
my %used = (); # items that are used by at least one other item

open (my $table_fh, '<', $table_file)
  or croak ('Error: unable to open the dependency table file at ', $table_file, '.', "\n");
while (defined (my $table_line = <$table_fh>)) {
  chomp $table_line;

  if ($table_line =~ / \s{2} /x) {
    croak ('Error: a line in the supplied dependency table has multiple consecutive spaces.', "\n");
  }
  if ($table_line =~ /\A \s /x) {
    croak ('Error: a line in the supplied dependency table begins with a space.', "\n");
  }
  if ($table_line =~ /\A \z/x) {
    croak ('Error: there is a blank line in the supplied dependency table.', "\n");
  }

  my ($item, my @deps) = split (/ /, $table_line);
  $dep_items{$item} = 0;
  $all_items{$item} = 0;
  $table{$item} = \@deps;
  foreach my $dep (@deps) {
    $all_items{$dep} = 0;
    $used{$dep} = 0;
  }
  if (scalar @deps == 0) {
    $trivial_dep_items{$item} = 0;
  } else {
    $non_trivial_dep_items{$item} = 0;
  }
}
close $table_fh
  or croak ('Error: unable to close the input filehandle for ', $table_file, '.', "\n");

sub escape_item {
  my $item = shift;
  $item =~ s/\[/\\[/;
  $item =~ s/\]/\\]/;
  return $item;
}

sub all {
  print join ("\n", keys %all_items), "\n";
}

sub dependent_items {
  if (scalar keys %dep_items > 0) {
    print join ("\n", keys %dep_items), "\n";
  }
}

sub implicitly_independent_items {
  foreach my $item (keys %all_items) {
    if (! defined $dep_items{$item}) {
      print $item, "\n";
    }
  }
}

sub explicitly_independent_items {
  if (scalar keys %trivial_dep_items > 0) {
    print join ("\n", keys %trivial_dep_items), "\n";
  }
}

sub independent_items {
  print join ("\n", keys %trivial_dep_items);
  implicitly_independent_items ();
}

sub dependencies_of {
  if (scalar @ARGV != 2) {
    pod2usage (1);
  }
  my $item = $ARGV[1];
  if (defined $table{$item}) {
    my @deps = @{$table{$item}};
    print join ("\n", @deps), "\n";
  }
}

sub items_depending_on {
  if (scalar @ARGV != 2) {
    pod2usage (1);
  }
  my $item = $ARGV[1];
  my $item_escaped = escape_item ($item);
  foreach my $other_item (keys %dep_items) {
    my @deps = @{$table{$other_item}};
    if (grep { / \A $item_escaped \z/x } @deps) {
      print $other_item, "\n";
    }
  }
}

sub random_item {
  my @items = keys %all_items;
  my $random_number = rand scalar @items;
  my $random_item = $items[$random_number];
  print $random_item, "\n";
}

sub dependencies_of_random_item {
  my @items_with_deps = keys %non_trivial_dep_items;
  if (scalar @items_with_deps == 0) {
    croak ('Error: there are no items that have a non-empty list of dependencies.', "\n");
  } else {
    my $random_number = rand scalar @items_with_deps;
    my $random_item = $items_with_deps[$random_number];
    if (defined $table{$random_item}) {
      my @deps = @{$table{$random_item}};
      print join ("\n", @deps), "\n";
    } else {
      croak ('Error: we computed ', $random_item, ' as a random item, but somehow we cannot find this item in our dependency table.');
    }
  }
}

sub tsort {
  my $split_vertices_fh = File::Temp->new ();
  my $split_vertices_path = $split_vertices_fh->filename ();
  foreach my $item (keys %dep_items) {
    my @deps = @{$table{$item}};
    foreach my $dep (@deps) {
      print {$split_vertices_fh} $item, ' ', $dep, "\n";
    }
  }
  close $split_vertices_fh
    or croak ('Error: unable to close the output filehandle for the temporary file created to reformat ', $table_file, ' so that we may call tsort.', "\n");
  my $tsort_error_fh = File::Temp->new ();
  my $tsort_output_fh = File::Temp->new ();
  my $tsort_error_path = $tsort_error_fh->filename ();
  my $tsort_output_path = $tsort_output_fh->filename ();
  my $tsort_status
    = system ("tsort $split_vertices_path > $tsort_output_path 2> $tsort_error_path");
  my $tsort_exit_code = $tsort_status >> 8;
  if ($tsort_exit_code != 0) {
    croak ('Error: tsort did not exit cleanly.', "\n");
  }
  if (-s $tsort_error_path) {
    my @tsort_errors = `cat $tsort_error_path`;
    croak ('Error: although tsort exited cleanly, it did report some errors:', "\n", join ("\n", @tsort_errors), "\n");
  }
  system ("cat $tsort_output_path");

  # Now print the items that appear in the table but don't have known
  # dependencies, as well as the items that have zero known
  # dependencies.

  foreach my $item (keys %all_items) {
    if (defined $table{$item}) {
      my @deps = @{$table{$item}};
      if (@deps == 0) {
	print $item, "\n";
      }
    } else {
      print $item, "\n";
    }
  }

}

sub items_independent_of {
  if (scalar @ARGV != 2) {
    pod2usage (1);
  }
  my $item = $ARGV[1];
  my $item_escaped = escape_item ($item);
  foreach my $other_item (keys %all_items) {
    # Does $other_item have any dependencies at all
    if (defined $table{$other_item}) {
      my @deps = @{$table{$other_item}};
      # Does $other_item have an empty list of dependencies?
      if (scalar @deps == 0) {
	# If so, then it is independent of $item
      } else {
	if (grep { /\A $item_escaped \z/x } @deps) {
	  # $other_item does depend on $item, so don't print anything
	} else {
	  # We didn't find $item among the dependencies of $other_item
	  print $other_item, "\n";
	}
      }
    } else {
      # If not, then it is independent of $item
      print $other_item, "\n";
    }
  }
}

# Items that are not used by any other item
sub unused {
  my @items_with_non_trivial_deps = keys %non_trivial_dep_items;
  my $num_items_with_non_trivial_deps = scalar @items_with_non_trivial_deps;
  foreach my $item (keys %all_items) {
    my $item_escaped = $item;
    $item_escaped =~ s/\[/\\[/;
    $item_escaped =~ s/\]/\\]/;
    my $user_found = 0;
    my $i = 0;
    while ($i < $num_items_with_non_trivial_deps && ! $user_found) {
      my $other_item = $items_with_non_trivial_deps[$i];
      my @deps = @{$table{$other_item}};
      if (grep { /\A $item_escaped \z /x } @deps) {
	$user_found = 1;
      } else {
	$i++;
      }
    }
    if (! $user_found) {
      print $item, "\n";
    }
  }
}

sub used {
  if (scalar keys %used > 0) {
    print join ("\n", keys %used), "\n";
  }
}

sub sort_table {
  foreach my $item (sort keys %all_items) {
    print $item;
    if (defined $table{$item}) {
      my @deps = @{$table{$item}};
      if (scalar @deps > 0) {
	print ' ', join (' ', sort @deps);
      }
    }
    print "\n";
  }
}

sub shuffle_table {
  my @items = keys %all_items;
  my @shuffled_items = shuffle (@items);
  foreach my $item (@shuffled_items) {
    print $item;
    if (defined $table{$item}) {
      my @deps = @{$table{$item}};
      my @shuffled_deps = shuffle (@deps);
      print ' ', join (' ', @shuffled_deps);
    }
    print "\n";
  }
}

sub complete_table {
  foreach my $item (keys %all_items) {
    print $item;
    if (defined $table{$item}) {
      my @deps = @{$table{$item}};
      if (@deps) {
	print ' ', join (' ', @deps);
      }
    }
    print "\n";
  }
}

sub invert_table {

  my %inverted = ();

  foreach my $item (keys %all_items) {
    if (defined $table{$item}) {
      my @deps = @{$table{$item}};
      foreach my $dep (@deps) {
	if (defined $inverted{$dep}) {
	  my @inverse_deps = @{$inverted{$dep}};
	  push (@inverse_deps, $item);
	  $inverted{$dep} = \@inverse_deps;
	} else {
	  my @first_inversion = ();
	  push (@first_inversion, $item);
	  $inverted{$dep} = \@first_inversion;
	}
      }
    }
  }

  foreach my $item (keys %all_items) {
    print $item;
    if (defined $inverted{$item}) {
      my @inverse_deps = @{$inverted{$item}};
      print ' ', join (' ', @inverse_deps);
    }
    print "\n";
  }

}

&{$command_dispatch_table{$command}};


__END__

=pod

=head1 NAME

B<table-info.pl>: Print information about a dependency table

=head1 SYNOPSIS

B<table-info.pl>: <dependency-table> <command> [arguments]

=head1 OPTIONS

=over 8

=back

=head

=cut
