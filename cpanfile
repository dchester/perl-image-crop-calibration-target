requires 'Image::Magick';
requires 'Graphics::ColorObject';
requires 'File::Slurp';

on 'test' => sub {
	requires 'Test::More';
	requires 'Digest::MD5';
};
