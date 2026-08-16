package com.qa.loanservice.controller;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.qa.loanservice.exception.GlobalExceptionHandler;
import com.qa.loanservice.exception.LoanNotFoundException;
import com.qa.loanservice.model.Loan;
import com.qa.loanservice.model.LoanStatus;
import com.qa.loanservice.model.requests.CreateLoanRequest;
import com.qa.loanservice.model.requests.UpdateLoanStatusRequest;
import com.qa.loanservice.service.LoanService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.context.annotation.Import;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

import java.util.List;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest(LoanController.class)
@Import(GlobalExceptionHandler.class)
class LoanControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @MockBean
    private LoanService loanService;

    @Test
    void getAllLoans_returns200() throws Exception {
        when(loanService.getAllLoans()).thenReturn(
                List.of(new Loan(101L, "Rahul", 500_000L, LoanStatus.APPROVED)));

        mockMvc.perform(get("/api/loans"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].id").value(101))
                .andExpect(jsonPath("$[0].customerName").value("Rahul"));
    }

    @Test
    void getLoanById_returns200() throws Exception {
        when(loanService.getLoanById(101L))
                .thenReturn(new Loan(101L, "Rahul", 500_000L, LoanStatus.APPROVED));

        mockMvc.perform(get("/api/loans/101"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("APPROVED"));
    }

    @Test
    void getLoanById_whenNotFound_returns404() throws Exception {
        when(loanService.getLoanById(999L)).thenThrow(new LoanNotFoundException(999L));

        mockMvc.perform(get("/api/loans/999"))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.status").value(404))
                .andExpect(jsonPath("$.message").value("Loan not found with id: 999"));
    }

    @Test
    void createLoan_returns201() throws Exception {
        CreateLoanRequest request = new CreateLoanRequest();
        request.setCustomerName("Amit");
        request.setAmount(300_000L);

        when(loanService.createLoan(any(CreateLoanRequest.class)))
                .thenReturn(new Loan(103L, "Amit", 300_000L, LoanStatus.PENDING));

        mockMvc.perform(post("/api/loans")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.id").value(103))
                .andExpect(jsonPath("$.status").value("PENDING"));
    }

    @Test
    void createLoan_withInvalidData_returns400() throws Exception {
        CreateLoanRequest request = new CreateLoanRequest();
        request.setCustomerName("");
        request.setAmount(0L);

        mockMvc.perform(post("/api/loans")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.status").value(400))
                .andExpect(jsonPath("$.message").exists());
    }

    @Test
    void updateLoanStatus_returns200() throws Exception {
        UpdateLoanStatusRequest request = new UpdateLoanStatusRequest();
        request.setStatus(LoanStatus.APPROVED);

        when(loanService.updateStatus(eq(101L), any(UpdateLoanStatusRequest.class)))
                .thenReturn(new Loan(101L, "Rahul", 500_000L, LoanStatus.APPROVED));

        mockMvc.perform(put("/api/loans/101/status")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("APPROVED"));
    }

    @Test
    void deleteLoan_returns204() throws Exception {
        mockMvc.perform(delete("/api/loans/101"))
                .andExpect(status().isNoContent());

        verify(loanService).deleteLoan(101L);
    }

    @Test
    void deleteLoan_whenNotFound_returns404() throws Exception {
        doThrow(new LoanNotFoundException(999L)).when(loanService).deleteLoan(999L);

        mockMvc.perform(delete("/api/loans/999"))
                .andExpect(status().isNotFound());
    }
}
