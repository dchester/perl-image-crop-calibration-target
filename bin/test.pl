use strict;

use Image::Crop::CalibrationTarget;
use File::Slurp qw(read_file write_file);

my $input_filename = shift @ARGV;
my $output_filename = shift @ARGV;

my $contents = read_file($input_filename, { binmode => 'raw' });

my $crop = Image::Crop::CalibrationTarget->new(
	image_data => $contents,
	debug => 1,
);

my $image_data = $crop->image_data;

write_file($output_filename, { binmode => 'raw' }, $image_data);

print "cropped.\n" if $crop->cropped;

