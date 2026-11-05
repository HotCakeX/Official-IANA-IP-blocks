//! Minimal HTTPS GET client built on the native Windows WinHTTP API.

#[cfg(windows)]
pub fn get(url: &str) -> std::io::Result<Vec<u8>> {
    winhttp::get(url)
}

#[cfg(not(windows))]
pub fn get(url: &str) -> std::io::Result<Vec<u8>> {
    Err(std::io::Error::new(
        std::io::ErrorKind::Unsupported,
        format!(
            "Downloading {url} is only supported on Windows. Use --offline to process the existing IANASources files."
        ),
    ))
}

#[cfg(windows)]
mod winhttp {
    use std::ffi::c_void;
    use std::io;
    use std::ptr;

    type HInternet = *mut c_void;

    const WINHTTP_ACCESS_TYPE_AUTOMATIC_PROXY: u32 = 4;
    const INTERNET_DEFAULT_HTTPS_PORT: u16 = 443;
    const WINHTTP_FLAG_SECURE: u32 = 0x0080_0000;
    const WINHTTP_OPTION_DECOMPRESSION: u32 = 118;
    // WINHTTP_DECOMPRESSION_FLAG_GZIP | WINHTTP_DECOMPRESSION_FLAG_DEFLATE
    const WINHTTP_DECOMPRESSION_FLAG_ALL: u32 = 0x1 | 0x2;
    const WINHTTP_QUERY_STATUS_CODE: u32 = 19;
    const WINHTTP_QUERY_CONTENT_LENGTH: u32 = 5;
    const WINHTTP_QUERY_FLAG_NUMBER: u32 = 0x2000_0000;
    const WINHTTP_QUERY_FLAG_NUMBER64: u32 = 0x0800_0000;

    const READ_CHUNK: usize = 1 << 20;

    #[link(name = "winhttp")]
    unsafe extern "system" {
        fn WinHttpOpen(
            agent: *const u16,
            access_type: u32,
            proxy: *const u16,
            proxy_bypass: *const u16,
            flags: u32,
        ) -> HInternet;
        fn WinHttpConnect(
            session: HInternet,
            server_name: *const u16,
            server_port: u16,
            reserved: u32,
        ) -> HInternet;
        fn WinHttpOpenRequest(
            connect: HInternet,
            verb: *const u16,
            object_name: *const u16,
            version: *const u16,
            referrer: *const u16,
            accept_types: *const *const u16,
            flags: u32,
        ) -> HInternet;
        fn WinHttpSetOption(
            internet: *const c_void,
            option: u32,
            buffer: *const c_void,
            buffer_length: u32,
        ) -> i32;
        fn WinHttpSendRequest(
            request: HInternet,
            headers: *const u16,
            headers_length: u32,
            optional: *const c_void,
            optional_length: u32,
            total_length: u32,
            context: usize,
        ) -> i32;
        fn WinHttpReceiveResponse(request: HInternet, reserved: *mut c_void) -> i32;
        fn WinHttpQueryHeaders(
            request: HInternet,
            info_level: u32,
            name: *const u16,
            buffer: *mut c_void,
            buffer_length: *mut u32,
            index: *mut u32,
        ) -> i32;
        fn WinHttpReadData(
            request: HInternet,
            buffer: *mut c_void,
            bytes_to_read: u32,
            bytes_read: *mut u32,
        ) -> i32;
        fn WinHttpCloseHandle(internet: HInternet) -> i32;
    }

    /// Owns a WinHTTP handle and closes it on drop.
    struct Handle(HInternet);

    impl Handle {
        fn new(handle: HInternet, what: &str) -> io::Result<Self> {
            if handle.is_null() {
                Err(last_error(what))
            } else {
                Ok(Self(handle))
            }
        }
    }

    impl Drop for Handle {
        fn drop(&mut self) {
            unsafe { WinHttpCloseHandle(self.0) };
        }
    }

    fn last_error(what: &str) -> io::Error {
        let err = io::Error::last_os_error();
        io::Error::new(err.kind(), format!("{what} failed: {err}"))
    }

    fn check(result: i32, what: &str) -> io::Result<()> {
        if result == 0 {
            Err(last_error(what))
        } else {
            Ok(())
        }
    }

    fn wide(s: &str) -> Vec<u16> {
        s.encode_utf16().chain(std::iter::once(0)).collect()
    }

    pub fn get(url: &str) -> io::Result<Vec<u8>> {
        let rest = url.strip_prefix("https://").ok_or_else(|| {
            io::Error::new(
                io::ErrorKind::InvalidInput,
                format!("Only https URLs are supported: {url}"),
            )
        })?;
        let (host, path) = rest.split_at(rest.find('/').unwrap_or(rest.len()));
        let path = if path.is_empty() { "/" } else { path };

        let agent = wide(concat!(
            env!("CARGO_PKG_NAME"),
            "/",
            env!("CARGO_PKG_VERSION")
        ));
        let host_w = wide(host);
        let path_w = wide(path);
        let verb_w = wide("GET");

        unsafe {
            let session = Handle::new(
                WinHttpOpen(
                    agent.as_ptr(),
                    WINHTTP_ACCESS_TYPE_AUTOMATIC_PROXY,
                    ptr::null(),
                    ptr::null(),
                    0,
                ),
                "WinHttpOpen",
            )?;

            let connect = Handle::new(
                WinHttpConnect(session.0, host_w.as_ptr(), INTERNET_DEFAULT_HTTPS_PORT, 0),
                "WinHttpConnect",
            )?;

            let request = Handle::new(
                WinHttpOpenRequest(
                    connect.0,
                    verb_w.as_ptr(),
                    path_w.as_ptr(),
                    ptr::null(),
                    ptr::null(),
                    ptr::null(),
                    WINHTTP_FLAG_SECURE,
                ),
                "WinHttpOpenRequest",
            )?;

            // Let the server send gzip/deflate compressed content; WinHTTP decompresses it transparently.
            // Failure only means no compression, so the result is intentionally ignored.
            let decompression: u32 = WINHTTP_DECOMPRESSION_FLAG_ALL;
            WinHttpSetOption(
                request.0,
                WINHTTP_OPTION_DECOMPRESSION,
                (&raw const decompression).cast(),
                size_of::<u32>() as u32,
            );

            check(
                WinHttpSendRequest(request.0, ptr::null(), 0, ptr::null(), 0, 0, 0),
                "WinHttpSendRequest",
            )?;
            check(
                WinHttpReceiveResponse(request.0, ptr::null_mut()),
                "WinHttpReceiveResponse",
            )?;

            let mut status: u32 = 0;
            let mut status_len: u32 = size_of::<u32>() as u32;
            check(
                WinHttpQueryHeaders(
                    request.0,
                    WINHTTP_QUERY_STATUS_CODE | WINHTTP_QUERY_FLAG_NUMBER,
                    ptr::null(),
                    (&raw mut status).cast(),
                    &mut status_len,
                    ptr::null_mut(),
                ),
                "WinHttpQueryHeaders",
            )?;
            if !(200..300).contains(&status) {
                return Err(io::Error::other(format!(
                    "HTTP status {status} returned for {url}"
                )));
            }

            // Content-Length is only a capacity hint, it may be absent or refer to the compressed size.
            let mut content_length: u64 = 0;
            let mut content_length_len: u32 = size_of::<u64>() as u32;
            let has_length = WinHttpQueryHeaders(
                request.0,
                WINHTTP_QUERY_CONTENT_LENGTH | WINHTTP_QUERY_FLAG_NUMBER64,
                ptr::null(),
                (&raw mut content_length).cast(),
                &mut content_length_len,
                ptr::null_mut(),
            ) != 0;
            let initial_capacity = if has_length {
                usize::try_from(content_length).unwrap_or(0)
            } else {
                0
            };

            let mut body: Vec<u8> = Vec::with_capacity(initial_capacity.max(READ_CHUNK));
            loop {
                if body.capacity() - body.len() < READ_CHUNK {
                    body.reserve(READ_CHUNK);
                }
                let spare = body.spare_capacity_mut();
                let to_read = u32::try_from(spare.len()).unwrap_or(u32::MAX);
                let mut read: u32 = 0;
                check(
                    WinHttpReadData(request.0, spare.as_mut_ptr().cast(), to_read, &mut read),
                    "WinHttpReadData",
                )?;
                if read == 0 {
                    break;
                }
                body.set_len(body.len() + read as usize);
            }

            Ok(body)
        }
    }
}
