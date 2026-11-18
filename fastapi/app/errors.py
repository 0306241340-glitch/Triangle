"""Envelope giong het Express de Flutter khong phai doi 1 dong:
thanh cong {ok:true, data}, loi {ok:false, error:{code, message}}."""
class ApiError(Exception):
    def __init__(self, status: int, code: str, message: str):
        super().__init__(message)
        self.status = status
        self.code = code
        self.message = message

def ok(data):
    return {"ok": True, "data": data}

def fail_body(code: str, message: str):
    return {"ok": False, "error": {"code": code, "message": message}}
