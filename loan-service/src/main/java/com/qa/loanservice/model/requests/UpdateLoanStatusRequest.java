package com.qa.loanservice.model.requests;

import com.qa.loanservice.model.LoanStatus;
import jakarta.validation.constraints.NotNull;

public class UpdateLoanStatusRequest {

    @NotNull(message = "Status is required")
    private LoanStatus status;

    public LoanStatus getStatus() {
        return status;
    }

    public void setStatus(LoanStatus status) {
        this.status = status;
    }
}
