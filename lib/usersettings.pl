#!/usr/bin/perl
# Read and change options in the game's UserSettings.json without reformatting it.
#
#   usersettings.pl get  <file> <group> <name>           prints the value
#   usersettings.pl set  <file> <group> <name> <value>   changes the value (and "index" for list options)
#   usersettings.pl dump <file> <group>                  prints name=value for every option of a group
#
# Groups are the file's group_name, e.g. /graphics/presets. Only the option's "value" (and "index") lines are rewritten,
# in place, so the file keeps the game's own layout; the result is checked to still be valid JSON.
# Uses only Perl modules that ship with macOS.
use strict;
use warnings;
use JSON::PP;

my ($cmd, $file, $group, $name, $value) = @ARGV;
die "usage: usersettings.pl get|set|dump <file> <group> [name] [value]\n" unless $cmd && $file && $group;

open my $fh, '<:raw', $file or die "cannot read $file: $!\n";
my $text = do { local $/; <$fh> };
close $fh;
my $json = JSON::PP->new->allow_nonref;
my $data = $json->decode($text);

my ($grp) = grep { $_->{group_name} eq $group } @{ $data->{data} };
die "no group $group in $file\n" unless $grp;

sub show { my $v = shift; return JSON::PP::is_bool($v) ? ($v ? 'true' : 'false') : $v }

if ($cmd eq 'dump') {
    print "$_->{name}=", show($_->{value}), "\n" for @{ $grp->{options} };
    exit 0;
}

my ($opt) = grep { $_->{name} eq $name } @{ $grp->{options} };
die "no option $name in $group\n" unless $opt;

if ($cmd eq 'get') {
    print show($opt->{value}), "\n";
    exit 0;
}
die "unknown command $cmd\n" unless $cmd eq 'set' && defined $value;

# The new value as JSON text, and the list index for list options.
my $type = $opt->{type} // '';
my ($new, $index);
if ($type =~ /_list$/) {
    my @values = @{ $opt->{values} };
    ($index) = grep { show($values[$_]) eq $value } 0 .. $#values;
    die "$name has no value '$value' (choices: @{[ map { show($_) } @values ]})\n" unless defined $index;
    $new = $json->encode($values[$index]);
} elsif ($type eq 'bool') {
    die "$name takes true or false\n" unless $value =~ /^(true|false)$/;
    $new = $value;
} elsif ($type eq 'int') {
    die "$name takes a whole number\n" unless $value =~ /^-?\d+$/;
    $new = $value;
} elsif ($type eq 'float') {
    die "$name takes a number\n" unless $value =~ /^-?\d+(\.\d+)?$/;
    $new = $value =~ /\./ ? $value : "$value.0";
} else {
    $new = $json->encode($value);
}

# Find the option's object in the text: after the group's group_name, the line with this option's name.
my $gpos = index($text, qq("group_name": "$group"));
die "group $group not found in the text\n" if $gpos < 0;
my $npos = index($text, qq("name": "$name"), $gpos);
die "option $name not found in the text\n" if $npos < 0;
my $end = index($text, '"name":', $npos + 1);      # the next option (or group) starts after this object
$end = length($text) if $end < 0;
my $obj = substr($text, $npos, $end - $npos);

$obj =~ s/("value":\s*)(?:"(?:[^"\\]|\\.)*"|[^,\n}]+)/$1$new/ or die "no value line for $name\n";
if (defined $index) {
    $obj =~ s/("index":\s*)\d+/$1$index/ or die "no index line for $name\n";
}
substr($text, $npos, $end - $npos) = $obj;

# Must still parse, and must now hold the new value.
my $check = $json->decode($text);
my ($cg) = grep { $_->{group_name} eq $group } @{ $check->{data} };
my ($co) = grep { $_->{name} eq $name } @{ $cg->{options} };
die "edit did not take effect\n" unless show($co->{value}) eq show($json->decode($new));

my $tmp = "$file.ripperdoc-tmp";
open my $out, '>:raw', $tmp or die "cannot write $tmp: $!\n";
print $out $text;
close $out or die "cannot write $tmp: $!\n";
rename $tmp, $file or die "cannot replace $file: $!\n";
