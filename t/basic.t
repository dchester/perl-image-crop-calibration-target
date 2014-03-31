use strict;

use Test::More;

use Image::Crop::CalibrationTarget;
use Digest::MD5 qw(md5_hex);

use File::Slurp qw(read_file write_file);

my $data = read_file('t/data/image.jpg', { binmode => 'raw' });

my $crop = Image::Crop::CalibrationTarget->new( image_data => $data );

is(md5_hex($crop->image_data), 'dd066ebfde92cc27a5af647481829ea2', 'cropped image data looks good');
is($crop->cropped, 1, 'image to be cropped is cropped');
is($crop->crop_orientation, 'left', 'left target has left crop orientation');
is(abs($crop->crop_percent - .106666666666667) < 0.001 ? 1 : 0, 1, 'crop percent is about 10');

done_testing;




